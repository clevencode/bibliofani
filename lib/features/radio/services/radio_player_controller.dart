import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
    isLiveMode: true,
  );
}

class RadioPlayerController extends StateNotifier<RadioPlayerState> {
  static const Duration _minActionInterval = Duration(milliseconds: 550);
  static const Duration _stallThreshold = Duration(seconds: 15);
  static final AudioPlayer _sharedPlayer = AudioPlayer();

  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  StreamSubscription<Object>? _errorSub;
  bool _sourceConfigured = false;
  bool _hasPlaybackAttempted = false;
  bool _isSwitchingSource = false;
  Future<void>? _sourceLock;
  final Random _random = Random();
  Timer? _stallWatchdog;
  DateTime? _lastActionAt;

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

      state = state.copyWith(
        lifecycle: lifecycle,
        errorMessage: processing == ProcessingState.idle &&
                _hasPlaybackAttempted &&
                !_isSwitchingSource
            ? 'Falha ao carregar o stream'
            : null,
      );

      _syncStallWatchdog(lifecycle);
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

    _positionSub = _player.positionStream.listen((position) {
      state = state.copyWith(elapsed: position);
    });

    unawaited(_bootstrapAutoPlay());
  }

  Future<void> _bootstrapAutoPlay() async {
    try {
      await _configureSource(forceRefresh: true);
      await _playWithRetry();
    } catch (e, st) {
      debugPrint('Falha ao iniciar reproducao automatica: $e');
      debugPrint(st.toString());
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Nao foi possivel iniciar o audio automaticamente',
      );
    }
  }

  Future<void> _configureSource({bool forceRefresh = false}) async {
    if (_sourceConfigured && !forceRefresh) return;
    if (_sourceLock != null) return _sourceLock!;

    final completer = Completer<void>();
    _sourceLock = completer.future;

    try {
      _isSwitchingSource = true;
      final uri = Uri.parse(kRadioStreamUrl);
      final liveUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      await _player.setAudioSource(
        AudioSource.uri(liveUri),
        preload: false,
      );
      _sourceConfigured = true;
      completer.complete();
    } catch (e, st) {
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
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.preparing,
        errorMessage: null,
      );
      await _configureSource();
      await _playWithRetry();
    } catch (_) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Erro ao preparar o stream',
      );
    }
  }

  Future<void> goLive() async {
    if (!_allowActionNow()) return;
    if (state.isBuffering) return;
    try {
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
        errorMessage: 'Erro ao reconectar ao vivo',
        isLiveMode: false,
      );
    } finally {
      _isSwitchingSource = false;
    }
  }

  Future<void> _playWithRetry({int maxAttempts = 8}) async {
    _hasPlaybackAttempted = true;
    state = state.copyWith(errorMessage: null);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _player.play();
        state = state.copyWith(lifecycle: RadioPlaybackLifecycle.playing);
        return;
      } catch (e, st) {
        debugPrint('Tentativa $attempt de play falhou: $e');
        debugPrint(st.toString());
        _errorController.add(e);
        if (attempt == maxAttempts) {
          state = state.copyWith(
            lifecycle: RadioPlaybackLifecycle.error,
            errorMessage: 'Erro ao iniciar o stream. Verifique sua conexão.',
          );
          return;
        }
        final baseMs = 300 * (1 << (attempt - 1));
        final jitterMs = _random.nextInt(240);
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
        lifecycle == RadioPlaybackLifecycle.reconnecting;

    if (!watching) {
      _stallWatchdog?.cancel();
      _stallWatchdog = null;
      return;
    }

    _stallWatchdog ??= Timer(_stallThreshold, () {
      debugPrint('Watchdog detectou stall no stream');
      unawaited(_recoverFromStall());
    });
  }

  Future<void> _recoverFromStall() async {
    if (_isSwitchingSource) return;
    try {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.reconnecting,
        errorMessage: 'Reconectando stream...',
      );
      _isSwitchingSource = true;
      await _player.stop();
      await _configureSource(forceRefresh: true);
      await _playWithRetry(maxAttempts: 8);
    } catch (e, st) {
      debugPrint('Falha na recuperacao de stall: $e');
      debugPrint(st.toString());
      _handlePlaybackError(e);
    } finally {
      _isSwitchingSource = false;
      _stallWatchdog?.cancel();
      _stallWatchdog = null;
    }
  }

  void _handlePlaybackError(Object error) {
    if (state.lifecycle == RadioPlaybackLifecycle.error &&
        state.errorMessage != null) {
      return;
    }
    state = state.copyWith(
      lifecycle: RadioPlaybackLifecycle.error,
      errorMessage: error.toString(),
    );
  }

  @override
  void dispose() {
    _stallWatchdog?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _eventSub?.cancel();
    _errorSub?.cancel();
    _errorController.close();
    // Mantemos uma instancia singleton do player para evitar
    // reinicializacoes concorrentes do just_audio_background.
    super.dispose();
  }
}

final radioPlayerProvider =
    StateNotifierProvider<RadioPlayerController, RadioPlayerState>(
  (ref) => RadioPlayerController(),
);

