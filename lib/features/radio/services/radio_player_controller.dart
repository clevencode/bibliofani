import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/core/audio/audio_runtime_config.dart';
import 'package:meu_app/core/constants/stream_config.dart';

const _noStateChange = Object();

enum RadioPlaybackLifecycle {
  idle,
  preparing,
  buffering,
  playing,
  paused,
  reconnecting,
  error,
}

enum BufferingProfile {
  stable,
  ultra,
}

class RadioPlayerState {
  const RadioPlayerState({
    required this.lifecycle,
    required this.elapsed,
    required this.errorMessage,
    required this.isLiveMode,
  });

  final RadioPlaybackLifecycle lifecycle;
  final Duration elapsed;
  final String? errorMessage;
  final bool isLiveMode;

  bool get isPlaying => lifecycle == RadioPlaybackLifecycle.playing;
  bool get isBuffering =>
      lifecycle == RadioPlaybackLifecycle.preparing ||
      lifecycle == RadioPlaybackLifecycle.buffering ||
      lifecycle == RadioPlaybackLifecycle.reconnecting;

  RadioPlayerState copyWith({
    RadioPlaybackLifecycle? lifecycle,
    Duration? elapsed,
    Object? errorMessage = _noStateChange,
    bool? isLiveMode,
  }) {
    return RadioPlayerState(
      lifecycle: lifecycle ?? this.lifecycle,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _noStateChange)
          ? this.errorMessage
          : errorMessage as String?,
      isLiveMode: isLiveMode ?? this.isLiveMode,
    );
  }

  static const initial = RadioPlayerState(
    lifecycle: RadioPlaybackLifecycle.idle,
    elapsed: Duration.zero,
    errorMessage: null,
    isLiveMode: false,
  );
}

class RadioPlayerController extends StateNotifier<RadioPlayerState> {
  static const Duration _minActionInterval = Duration(milliseconds: 450);
  static const Duration _recoveryWindow = Duration(minutes: 1);
  static final AudioPlayer _sharedPlayer = AudioPlayer(
    handleInterruptions: false,
  );

  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<Duration>? _bufferedPositionSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  StreamSubscription<Object>? _errorSub;
  bool _sourceConfigured = false;
  bool _hasPlaybackAttempted = false;
  bool _isSwitchingSource = false;
  Future<void>? _sourceLock;
  final List<Uri> _streamPool = kRadioStreamCandidateUrls
      .map(Uri.parse)
      .toList(growable: false);
  final Map<String, int> _endpointPenalty = <String, int>{};
  Uri? _activeStreamUri;
  int _endpointCursor = 0;
  final Random _random = Random();
  Timer? _stallWatchdog;
  Timer? _sessionTicker;
  Duration _sessionElapsed = Duration.zero;
  DateTime? _sessionTickAt;
  Duration _lastPosition = Duration.zero;
  DateTime? _lastProgressAt;
  Duration _lastBufferedPosition = Duration.zero;
  DateTime? _lastBufferedProgressAt;
  bool _isRecovering = false;
  bool _resumeAfterInterruption = false;
  int _stallSignals = 0;
  DateTime? _lastRecoveryAt;
  BufferingProfile _bufferingProfile = BufferingProfile.stable;
  DateTime _recoveryWindowStart = DateTime.now();
  int _recoveriesInWindow = 0;
  DateTime? _lastActionAt;

  Duration get _stallThreshold => _bufferingProfile == BufferingProfile.stable
      ? const Duration(seconds: 12)
      : const Duration(seconds: 6);

  Duration get _watchdogTick => _bufferingProfile == BufferingProfile.stable
      ? const Duration(seconds: 4)
      : const Duration(seconds: 2);

  Duration get _recoveryCooldown => _bufferingProfile == BufferingProfile.stable
      ? const Duration(seconds: 4)
      : const Duration(seconds: 2);

  int get _stallSignalsBeforeRecover =>
      _bufferingProfile == BufferingProfile.stable ? 2 : 1;

  int get _maxRecoveriesPerWindow =>
      _bufferingProfile == BufferingProfile.stable ? 3 : 5;

  int get _retryAttempts => _bufferingProfile == BufferingProfile.stable ? 5 : 4;

  RadioPlayerController()
      : super(RadioPlayerState.initial) {
    _player = _sharedPlayer;

    _playerStateSub = _player.playerStateStream.listen((playerState) {
      final processing = playerState.processingState;
      final playing = playerState.playing;

      RadioPlaybackLifecycle lifecycle;
      if (_isSwitchingSource) {
        lifecycle = RadioPlaybackLifecycle.reconnecting;
      } else if (processing == ProcessingState.loading) {
        lifecycle = RadioPlaybackLifecycle.preparing;
      } else if (processing == ProcessingState.buffering) {
        lifecycle = RadioPlaybackLifecycle.buffering;
      } else if (playing && processing == ProcessingState.ready) {
        lifecycle = RadioPlaybackLifecycle.playing;
      } else if (!playing && processing == ProcessingState.ready) {
        lifecycle = RadioPlaybackLifecycle.paused;
      } else {
        lifecycle = RadioPlaybackLifecycle.idle;
      }

      Object? errorMessageUpdate = _noStateChange;
      if (processing == ProcessingState.idle &&
          _hasPlaybackAttempted &&
          !_isSwitchingSource &&
          !_isRecovering) {
        errorMessageUpdate = 'Échec du chargement du flux';
      } else if (lifecycle == RadioPlaybackLifecycle.playing ||
          lifecycle == RadioPlaybackLifecycle.paused) {
        errorMessageUpdate = null;
      }

      state = state.copyWith(
        lifecycle: lifecycle,
        errorMessage: errorMessageUpdate,
      );

      _syncStallWatchdog(lifecycle);
      _syncSessionClock(lifecycle);
    });

    _eventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace st) {
        debugPrint('Erro no playbackEventStream: $error');
        debugPrint(st.toString());
        _errorController.add(error);
      },
    );

    _errorSub = _errorController.stream.listen((error) {
      _handlePlaybackError(error);
    });

    _positionSub = _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 300),
          maxPeriod: const Duration(milliseconds: 900),
        )
        .listen((position) {
      if (position < _lastPosition) {
        _lastPosition = position;
        _lastProgressAt = DateTime.now();
      } else if (position > _lastPosition) {
        _lastProgressAt = DateTime.now();
        _lastPosition = position;
      }
    });

    _bufferedPositionSub = _player.bufferedPositionStream.listen((buffered) {
      if (buffered < _lastBufferedPosition) {
        _lastBufferedPosition = buffered;
        _lastBufferedProgressAt = DateTime.now();
      } else if (buffered > _lastBufferedPosition) {
        _lastBufferedPosition = buffered;
        _lastBufferedProgressAt = DateTime.now();
      }
    });

    unawaited(_bindAudioSessionEvents());
    unawaited(_bootstrapAutoPlay());
  }

  Future<void> _bindAudioSessionEvents() async {
    final session = await AudioSession.instance;

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.pause) {
          if (_player.playing) {
            _resumeAfterInterruption = true;
            unawaited(_player.pause());
            state = state.copyWith(
              lifecycle: RadioPlaybackLifecycle.paused,
              errorMessage: null,
            );
          }
          return;
        }
        if (event.type == AudioInterruptionType.duck) {
          unawaited(_player.setVolume(0.5));
        }
        return;
      }

      if (event.type == AudioInterruptionType.duck) {
        unawaited(_player.setVolume(1.0));
        return;
      }

      if (_resumeAfterInterruption && !_player.playing) {
        _resumeAfterInterruption = false;
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.preparing,
          errorMessage: null,
        );
        unawaited(_playWithRetry(maxAttempts: 3));
      }
    });

    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      if (!_player.playing) return;
      unawaited(_player.pause());
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.paused,
        errorMessage: 'Audio mis en pause après changement de sortie.',
      );
    });
  }

  void setBufferingProfile(BufferingProfile profile) {
    if (_bufferingProfile == profile) return;
    _bufferingProfile = profile;
    _stallSignals = 0;
    _stallWatchdog?.cancel();
    _stallWatchdog = null;
    _lastRecoveryAt = null;
    _resetRecoveryWindow();
    _syncStallWatchdog(state.lifecycle);
  }

  Future<void> _bootstrapAutoPlay() async {
    try {
      state = state.copyWith(isLiveMode: false);
      await _configureSource(forceRefresh: true);
      await _playWithRetry();
    } catch (e, st) {
      debugPrint('Falha ao iniciar reproducao automatica: $e');
      debugPrint(st.toString());
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Impossible de démarrer l\'audio automatiquement',
      );
    }
  }

  Future<void> _configureSource({bool forceRefresh = false}) async {
    if (_sourceConfigured && !forceRefresh) return;
    if (_sourceLock != null) return _sourceLock!;

    final completer = Completer<void>();
    _sourceLock = completer.future;
    Uri? selectedBaseUri;

    try {
      _isSwitchingSource = true;
      selectedBaseUri = _selectEndpoint(forceRotate: forceRefresh);
      final liveUri = selectedBaseUri.replace(queryParameters: {
        ...selectedBaseUri.queryParameters,
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      final source = AudioRuntimeConfig.backgroundEnabled
          ? AudioSource.uri(
              liveUri,
              tag: const MediaItem(
                id: 'biblefm-live',
                title: 'Bible FM • En direct',
                artist: 'Écoutez où que vous soyez',
                album: 'Bible FM',
                extras: {'isLive': true},
              ),
            )
          : AudioSource.uri(liveUri);

      await _player.setAudioSource(
        source,
        preload: true,
      );
      _activeStreamUri = selectedBaseUri;
      _sourceConfigured = true;
      completer.complete();
    } catch (e, st) {
      _registerEndpointFailure(selectedBaseUri ?? _activeStreamUri);
      _sourceConfigured = false;
      debugPrint('Falha ao configurar source: $e');
      debugPrint(st.toString());
      _errorController.add(e);
      completer.completeError(e, st);
      rethrow;
    } finally {
      _isSwitchingSource = false;
      _sourceLock = null;
    }
  }

  Future<void> togglePlayPause() async {
    if (!_allowActionNow()) return;
    if (state.isBuffering) return;

    if (_player.playing) {
      await _player.pause();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.paused,
        isLiveMode: false,
      );
      return;
    }

    try {
      _resetRecoveryWindow();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.preparing,
        errorMessage: null,
        isLiveMode: false,
      );
      await _configureSource();
      await _playWithRetry();
    } catch (_) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Erreur lors de la préparation du flux',
        isLiveMode: false,
      );
    }
  }

  Future<void> goLive() async {
    if (!_allowActionNow()) return;
    if (state.isBuffering) return;
    try {
      _resetRecoveryWindow();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.reconnecting,
        errorMessage: null,
        isLiveMode: true,
      );
      _isSwitchingSource = true;
      await _player.stop();
      await _configureSource(forceRefresh: true);
      _isSwitchingSource = false;
      await _playWithRetry();
    } catch (_) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Erreur lors de la reconnexion en direct',
        isLiveMode: false,
      );
    } finally {
      _isSwitchingSource = false;
    }
  }

  Future<void> stopForAppExit() async {
    try {
      _stallWatchdog?.cancel();
      _stallWatchdog = null;
      _sessionTicker?.cancel();
      _sessionTicker = null;
      _sessionTickAt = null;
      _sessionElapsed = Duration.zero;
      await _player.stop();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.idle,
        elapsed: Duration.zero,
        errorMessage: null,
        isLiveMode: false,
      );
    } catch (e, st) {
      debugPrint('Falha ao parar audio no encerramento: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _playWithRetry({int? maxAttempts}) async {
    _hasPlaybackAttempted = true;
    state = state.copyWith(errorMessage: null);
    final attempts = maxAttempts ?? _retryAttempts;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _player.play();
        _registerEndpointSuccess(_activeStreamUri);
        _recoveriesInWindow = 0;
        _stallSignals = 0;
        _lastProgressAt = DateTime.now();
        _lastBufferedProgressAt = DateTime.now();
        state = state.copyWith(lifecycle: RadioPlaybackLifecycle.playing);
        return;
      } catch (e, st) {
        debugPrint('Tentativa $attempt de play falhou: $e');
        debugPrint(st.toString());
        _registerEndpointFailure(_activeStreamUri);
        if (attempt == attempts) {
          _errorController.add(e);
          state = state.copyWith(
            lifecycle: RadioPlaybackLifecycle.error,
            errorMessage: 'Erreur au démarrage du flux. Vérifiez votre connexion.',
          );
          return;
        }
        try {
          _sourceConfigured = false;
          await _configureSource(forceRefresh: true);
        } catch (_) {
          // Continua com backoff; o proximo ciclo tenta novamente.
        }
        final exponential = 180 * (1 << (attempt - 1));
        final baseMs = exponential.clamp(180, 2000);
        final jitterMs = _random.nextInt(180);
        await Future<void>.delayed(Duration(milliseconds: baseMs + jitterMs));
      }
    }
  }

  bool _allowActionNow() {
    final now = DateTime.now();
    if (_lastActionAt != null &&
        now.difference(_lastActionAt!) < _minActionInterval) {
      return false;
    }
    _lastActionAt = now;
    return true;
  }

  void _syncStallWatchdog(RadioPlaybackLifecycle lifecycle) {
    final watching = lifecycle == RadioPlaybackLifecycle.preparing ||
        lifecycle == RadioPlaybackLifecycle.buffering ||
        lifecycle == RadioPlaybackLifecycle.reconnecting ||
        lifecycle == RadioPlaybackLifecycle.playing;

    if (!watching) {
      _stallWatchdog?.cancel();
      _stallWatchdog = null;
      return;
    }

    _lastProgressAt ??= DateTime.now();
    _lastBufferedProgressAt ??= DateTime.now();
    _stallWatchdog ??= Timer.periodic(_watchdogTick, (_) {
      if (_isSwitchingSource || _isRecovering) return;
      final lifecycleNow = state.lifecycle;

      final now = DateTime.now();
      final elapsedSinceProgress = now.difference(_lastProgressAt!);
      final elapsedSinceBufferedProgress = now.difference(_lastBufferedProgressAt!);
      final isStalledWhilePlaying =
          lifecycleNow == RadioPlaybackLifecycle.playing &&
          _player.playing &&
          _player.processingState == ProcessingState.ready &&
          elapsedSinceProgress >= _stallThreshold &&
          elapsedSinceBufferedProgress >= _stallThreshold;
      final isStalledWhileBuffering =
          (lifecycleNow == RadioPlaybackLifecycle.preparing ||
              lifecycleNow == RadioPlaybackLifecycle.buffering ||
              lifecycleNow == RadioPlaybackLifecycle.reconnecting) &&
          elapsedSinceProgress >= _stallThreshold &&
          elapsedSinceBufferedProgress >= _stallThreshold;

      if (isStalledWhilePlaying || isStalledWhileBuffering) {
        _stallSignals++;
      } else {
        _stallSignals = 0;
      }

      if (_stallSignals >= _stallSignalsBeforeRecover) {
        _stallSignals = 0;
        debugPrint('Watchdog detectou stall no stream');
        unawaited(_recoverFromStall(reason: 'watchdog'));
      }
    });
  }

  void _syncSessionClock(RadioPlaybackLifecycle lifecycle) {
    final shouldRun = lifecycle == RadioPlaybackLifecycle.playing ||
        lifecycle == RadioPlaybackLifecycle.preparing ||
        lifecycle == RadioPlaybackLifecycle.buffering ||
        lifecycle == RadioPlaybackLifecycle.reconnecting;

    if (!shouldRun) {
      _sessionTicker?.cancel();
      _sessionTicker = null;
      _sessionTickAt = null;
      return;
    }

    _sessionTickAt ??= DateTime.now();
    _sessionTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final last = _sessionTickAt ?? now;
      final diff = now.difference(last);
      _sessionTickAt = now;
      _sessionElapsed += diff;
      state = state.copyWith(elapsed: _sessionElapsed);
    });
  }

  Future<void> _recoverFromStall({String reason = 'unknown'}) async {
    if (_isSwitchingSource || _isRecovering) return;
    final now = DateTime.now();
    if (_lastRecoveryAt != null &&
        now.difference(_lastRecoveryAt!) < _recoveryCooldown) {
      return;
    }
    if (!_consumeRecoverySlot()) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Flux instable. Réessayez dans quelques instants.',
      );
      return;
    }
    _lastRecoveryAt = now;
    _isRecovering = true;
    try {
      debugPrint('Iniciando recuperacao de stall ($reason)');
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.reconnecting,
        errorMessage: 'Reconnexion au flux...',
      );
      _isSwitchingSource = true;
      _registerEndpointFailure(_activeStreamUri);
      await _player.stop();
      await _configureSource(forceRefresh: true);
      await _playWithRetry();
      _lastProgressAt = DateTime.now();
      _lastBufferedProgressAt = DateTime.now();
    } catch (e, st) {
      debugPrint('Falha na recuperacao de stall: $e');
      debugPrint(st.toString());
      _handlePlaybackError(e);
    } finally {
      _isRecovering = false;
      _isSwitchingSource = false;
    }
  }

  void _handlePlaybackError(Object error) {
    if (_isRecovering || _isSwitchingSource) return;
    state = state.copyWith(
      lifecycle: RadioPlaybackLifecycle.reconnecting,
      errorMessage: 'Échec du flux. Tentative de reconnexion...',
    );
    unawaited(_recoverFromStall(reason: 'central_error_handler'));
  }

  Uri _selectEndpoint({required bool forceRotate}) {
    if (_streamPool.length == 1) return _streamPool.first;

    final candidates = forceRotate && _activeStreamUri != null
        ? _streamPool.where((uri) => uri != _activeStreamUri).toList()
        : _streamPool;
    final minPenalty = candidates
        .map((uri) => _endpointPenalty[uri.toString()] ?? 0)
        .reduce(min);
    final healthiest = candidates
        .where((uri) => (_endpointPenalty[uri.toString()] ?? 0) == minPenalty)
        .toList(growable: false);
    final chosen = healthiest[_endpointCursor % healthiest.length];
    _endpointCursor++;
    return chosen;
  }

  void _registerEndpointFailure(Uri? uri) {
    if (uri == null) return;
    final key = uri.toString();
    _endpointPenalty[key] = (_endpointPenalty[key] ?? 0) + 1;
  }

  void _registerEndpointSuccess(Uri? uri) {
    if (uri == null) return;
    final key = uri.toString();
    final current = _endpointPenalty[key] ?? 0;
    if (current <= 1) {
      _endpointPenalty.remove(key);
    } else {
      _endpointPenalty[key] = current - 1;
    }
  }

  bool _consumeRecoverySlot() {
    final now = DateTime.now();
    if (now.difference(_recoveryWindowStart) > _recoveryWindow) {
      _recoveryWindowStart = now;
      _recoveriesInWindow = 0;
    }
    if (_recoveriesInWindow >= _maxRecoveriesPerWindow) {
      return false;
    }
    _recoveriesInWindow++;
    return true;
  }

  void _resetRecoveryWindow() {
    _recoveryWindowStart = DateTime.now();
    _recoveriesInWindow = 0;
  }

  @override
  void dispose() {
    _stallWatchdog?.cancel();
    _sessionTicker?.cancel();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _playerStateSub?.cancel();
    _eventSub?.cancel();
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _errorSub?.cancel();
    _errorController.close();
    super.dispose();
  }
}

final radioPlayerProvider =
    StateNotifierProvider<RadioPlayerController, RadioPlayerState>(
  (ref) {
    final controller = RadioPlayerController();
    ref.listen<BufferingProfile>(bufferingProfileProvider, (_, next) {
      controller.setBufferingProfile(next);
    });
    return controller;
  },
);

final bufferingProfileProvider =
    StateProvider<BufferingProfile>((ref) => BufferingProfile.stable);

