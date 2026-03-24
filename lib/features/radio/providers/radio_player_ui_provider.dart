import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';

/// Estado da UI do leitor + reprodução real ([AudioPlayer] + stream).
@immutable
class RadioPlayerUiState {
  const RadioPlayerUiState({
    required this.lifecycle,
    required this.elapsed,
    required this.isLiveMode,
    required this.livePulseActive,
    required this.liveSyncEligible,
    this.errorMessage,
  });

  factory RadioPlayerUiState.initial() => const RadioPlayerUiState(
        lifecycle: UiPlaybackLifecycle.idle,
        elapsed: Duration.zero,
        isLiveMode: false,
        livePulseActive: false,
        liveSyncEligible: true,
        errorMessage: null,
      );

  final UiPlaybackLifecycle lifecycle;
  final Duration elapsed;
  final bool isLiveMode;
  final bool livePulseActive;
  /// Após uma pausa, permite alinhar o contador ao direct; consome-se ao tocar em live até nova pausa.
  final bool liveSyncEligible;
  final String? errorMessage;

  bool get isPlaying => lifecycle == UiPlaybackLifecycle.playing;

  /// Direct: clicável fora de buffering.
  /// - Em pause: sempre permite (incluindo quando veio de live).
  /// - Em reprodução: apenas quando ainda não está em live (estado differe).
  bool get canTapLive =>
      !isBufferingUiLifecycle(lifecycle) &&
      (lifecycle == UiPlaybackLifecycle.paused || !isLiveMode);

  /// «En direct»: a tocar, sem buffer, com modo live.
  bool get isEnDirect =>
      isPlaying && !isBufferingUiLifecycle(lifecycle) && isLiveMode;

  /// O contador só avança em reprodução efectiva (não em buffering).
  bool get shouldRunElapsedTicker =>
      isPlaying && !isBufferingUiLifecycle(lifecycle);

  RadioPlayerUiState copyWith({
    UiPlaybackLifecycle? lifecycle,
    Duration? elapsed,
    bool? isLiveMode,
    bool? livePulseActive,
    bool? liveSyncEligible,
    Object? errorMessage = _sentinel,
  }) {
    return RadioPlayerUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      elapsed: elapsed ?? this.elapsed,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      livePulseActive: livePulseActive ?? this.livePulseActive,
      liveSyncEligible: liveSyncEligible ?? this.liveSyncEligible,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _sentinel = Object();
}

final radioPlayerUiProvider =
    StateNotifierProvider<RadioPlayerUiNotifier, RadioPlayerUiState>((ref) {
  return RadioPlayerUiNotifier();
});

/// Regras de negócio da UI + `just_audio` / notificação em segundo plano.
class RadioPlayerUiNotifier extends StateNotifier<RadioPlayerUiState> {
  RadioPlayerUiNotifier() : super(RadioPlayerUiState.initial()) {
    _player = AudioPlayer();
    _playerStateSub = _player.playerStateStream.listen(
      _onPlayerState,
      onError: _onPlayerStateError,
    );
  }

  void _onPlayerStateError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('RadioPlayerUiNotifier playerStateStream: $error\n$stack');
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'radio_player_ui_provider',
        context: ErrorDescription('playerStateStream'),
      ),
    );
  }

  /// Passo de «rattrapage» vers le direct (UI). Plusieurs taps après pause
  /// rapprochent le compteur du bord live sans le ramener à zéro d’un coup.
  static const Duration _liveCatchUpChunk = Duration(seconds: 30);

  /// Plancher après un tap live : ne pas effacer le contador (≠ 0).
  static const Duration _minElapsedAfterLiveTap = Duration(seconds: 1);

  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSub;

  Timer? _elapsedTicker;
  bool _autoLivePending = false;
  bool _sourceLoaded = false;
  /// Evita que o stream reconcile `idle` antes de `setAudioSource` avançar (race com «preparing»).
  bool _deferPlayerIdle = false;

  /// Avança o contador em direcção ao instante mais recente, em [chunk]s,
  /// sem [Duration.zero] imposto por um único toque.
  Duration _elapsedAfterLiveTap(Duration current, {required bool consumeSync}) {
    if (!consumeSync) return current;
    if (current <= Duration.zero) {
      return _minElapsedAfterLiveTap;
    }
    final reduced = current - _liveCatchUpChunk;
    if (reduced < _minElapsedAfterLiveTap) {
      return _minElapsedAfterLiveTap;
    }
    return reduced;
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    unawaited(_playerStateSub?.cancel() ?? Future<void>.value());
    unawaited(_player.dispose());
    super.dispose();
  }

  void _emit(RadioPlayerUiState next) {
    state = next;
    _syncElapsedTicker();
    _tryApplyPendingAutoLive();
  }

  void _cancelAutoLivePending() {
    _autoLivePending = false;
  }

  void _onPlayerState(PlayerState playerState) {
    if (_deferPlayerIdle &&
        playerState.processingState == ProcessingState.idle) {
      return;
    }
    if (playerState.processingState != ProcessingState.idle) {
      _deferPlayerIdle = false;
    }
    final ps = playerState.processingState;
    final playing = playerState.playing;

    final UiPlaybackLifecycle nextLifecycle;
    switch (ps) {
      case ProcessingState.idle:
        nextLifecycle = UiPlaybackLifecycle.idle;
        break;
      case ProcessingState.loading:
        nextLifecycle = UiPlaybackLifecycle.preparing;
        break;
      case ProcessingState.buffering:
        nextLifecycle = UiPlaybackLifecycle.buffering;
        break;
      case ProcessingState.ready:
        nextLifecycle =
            playing ? UiPlaybackLifecycle.playing : UiPlaybackLifecycle.paused;
        break;
      case ProcessingState.completed:
        nextLifecycle = UiPlaybackLifecycle.idle;
        break;
    }

    if (nextLifecycle != state.lifecycle) {
      state = state.copyWith(lifecycle: nextLifecycle);
      _syncElapsedTicker();
    }
    _tryApplyPendingAutoLive();
  }

  /// Mantém o [Timer.periodic] alinhado com [RadioPlayerUiState.shouldRunElapsedTicker].
  void _syncElapsedTicker() {
    if (state.shouldRunElapsedTicker) {
      _startElapsedTicker();
    } else {
      _stopElapsedTicker();
    }
  }

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (!s.shouldRunElapsedTicker) return;
      state = s.copyWith(elapsed: s.elapsed + const Duration(seconds: 1));
    });
  }

  void _stopElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

  void _tryApplyPendingAutoLive() {
    if (!_autoLivePending) return;
    if (!state.isPlaying || isBufferingUiLifecycle(state.lifecycle)) return;
    if (!state.canTapLive) return;
    _autoLivePending = false;
    liveTap();
  }

  AudioSource _liveSource() {
    return AudioSource.uri(
      Uri.parse(kBibleFmLiveStreamUrl),
      tag: MediaItem(
        id: 'biblefm-live',
        album: 'Bible FM',
        title: 'En direct',
      ),
    );
  }

  Future<void> _ensureSourceLoaded() async {
    if (_sourceLoaded) return;
    try {
      await _player.setAudioSource(_liveSource());
      _sourceLoaded = true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('RadioPlayerUiNotifier: setAudioSource failed: $e\n$stack');
      }
      rethrow;
    }
  }

  static String _loadErrorMessage(Object e) {
    final msg = e.toString();
    if (msg.length > 160) {
      return '${msg.substring(0, 157)}…';
    }
    return msg;
  }

  /// Arranque da app: inicia a reprodução e activa o modo **direct** (como play + live).
  Future<void> autoStartLivePlayback() async {
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    if (state.errorMessage != null) {
      _emit(state.copyWith(errorMessage: null));
    }
    _autoLivePending = true;
    try {
      await centralTap();
      _tryApplyPendingAutoLive();
    } catch (e, stack) {
      _cancelAutoLivePending();
      if (kDebugMode) {
        debugPrint('autoStartLivePlayback: $e\n$stack');
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'radio_player_ui_provider',
          context: ErrorDescription('autoStartLivePlayback'),
        ),
      );
    }
  }

  Future<void> centralTap() async {
    if (state.errorMessage != null) {
      _cancelAutoLivePending();
      _emit(state.copyWith(errorMessage: null));
      return;
    }

    switch (state.lifecycle) {
      case UiPlaybackLifecycle.preparing:
      case UiPlaybackLifecycle.buffering:
        _deferPlayerIdle = false;
        _cancelAutoLivePending();
        try {
          await _player.stop();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('stop during buffer: $e\n$stack');
        }
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.idle,
            isLiveMode: false,
            livePulseActive: false,
            liveSyncEligible: true,
            errorMessage: null,
          ),
        );
        return;

      case UiPlaybackLifecycle.playing:
        try {
          await _player.pause();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('pause: $e\n$stack');
        }
        _emit(
          state.copyWith(
            livePulseActive: false,
            liveSyncEligible: true,
          ),
        );
        return;

      case UiPlaybackLifecycle.paused:
        try {
          await _player.play();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('play: $e\n$stack');
        }
        _emit(
          state.copyWith(
            isLiveMode: false,
            livePulseActive: false,
          ),
        );
        return;

      case UiPlaybackLifecycle.idle:
        _deferPlayerIdle = true;
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.preparing,
            elapsed: Duration.zero,
            liveSyncEligible: true,
            isLiveMode: false,
            livePulseActive: false,
            errorMessage: null,
          ),
        );
        try {
          await _ensureSourceLoaded();
          await _player.play();
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('Radio start failed: $e\n$stack');
          }
          _deferPlayerIdle = false;
          _cancelAutoLivePending();
          _sourceLoaded = false;
          _emit(
            state.copyWith(
              lifecycle: UiPlaybackLifecycle.idle,
              errorMessage: _loadErrorMessage(e),
            ),
          );
        }
        return;
    }
  }

  void liveTap() {
    if (!state.canTapLive) return;
    final wasPaused = state.lifecycle == UiPlaybackLifecycle.paused;
    final sync = state.liveSyncEligible;
    final nextElapsed = _elapsedAfterLiveTap(
      state.elapsed,
      consumeSync: sync,
    );
    _emit(
      state.copyWith(
        isLiveMode: true,
        errorMessage: null,
        elapsed: nextElapsed,
        liveSyncEligible: false,
      ),
    );
    if (wasPaused) {
      unawaited(
        _player.play().catchError((Object e, StackTrace stack) {
          if (kDebugMode) debugPrint('liveTap play: $e\n$stack');
        }),
      );
    }
  }

  void resetElapsed() {
    _emit(state.copyWith(elapsed: Duration.zero));
  }

  void retryAfterError() {
    unawaited(_retryAfterErrorAsync());
  }

  Future<void> _retryAfterErrorAsync() async {
    try {
      await _player.stop();
    } catch (_) {}
    _deferPlayerIdle = false;
    _cancelAutoLivePending();
    _sourceLoaded = false;
    _emit(
      state.copyWith(
        errorMessage: null,
        lifecycle: UiPlaybackLifecycle.idle,
        livePulseActive: false,
        liveSyncEligible: true,
        isLiveMode: false,
      ),
    );
  }

  void toggleLivePulse() {
    if (!state.isEnDirect) return;
    _emit(state.copyWith(livePulseActive: !state.livePulseActive));
  }
}
