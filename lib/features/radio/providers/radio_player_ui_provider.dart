import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';

/// Estado da UI do leitor (mock): ciclo de leitura, contador e modo direct.
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

  /// Direct: disponível fora de buffering quando ainda não está em live
  /// (ex.: differe em reprodução ou pausa).
  bool get canTapLive => !isLiveMode && !isBufferingUiLifecycle(lifecycle);

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

/// Regras de negócio da UI: play/pause, live, contador e sincronização do timer.
class RadioPlayerUiNotifier extends StateNotifier<RadioPlayerUiState> {
  RadioPlayerUiNotifier() : super(RadioPlayerUiState.initial());

  /// Passo de «rattrapage» vers le direct (mock). Plusieurs taps après pause
  /// rapprochent le compteur du bord live sans le ramener à zéro d’un coup.
  static const Duration _liveCatchUpChunk = Duration(seconds: 30);

  /// Plancher après un tap live : ne pas effacer le contador (≠ 0).
  static const Duration _minElapsedAfterLiveTap = Duration(seconds: 1);

  Timer? _elapsedTicker;

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
    super.dispose();
  }

  void _emit(RadioPlayerUiState next) {
    state = next;
    _syncElapsedTicker();
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

  Future<void> centralTap() async {
    if (state.errorMessage != null) {
      _emit(state.copyWith(errorMessage: null));
      return;
    }

    switch (state.lifecycle) {
      case UiPlaybackLifecycle.preparing:
      case UiPlaybackLifecycle.buffering:
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.idle,
            isLiveMode: false,
            livePulseActive: false,
            liveSyncEligible: true,
          ),
        );
        return;

      case UiPlaybackLifecycle.playing:
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.paused,
            livePulseActive: false,
            liveSyncEligible: true,
          ),
        );
        return;

      case UiPlaybackLifecycle.paused:
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.playing,
            // Retomar pelo play volta para differe; só o botão live ativa live.
            isLiveMode: false,
            livePulseActive: false,
          ),
        );
        return;

      case UiPlaybackLifecycle.idle:
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.preparing,
            elapsed: Duration.zero,
            liveSyncEligible: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        _emit(state.copyWith(lifecycle: UiPlaybackLifecycle.buffering));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        _emit(state.copyWith(lifecycle: UiPlaybackLifecycle.playing));
        return;
    }
  }

  void liveTap() {
    if (!state.canTapLive) return;
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
        lifecycle: UiPlaybackLifecycle.playing,
        liveSyncEligible: false,
      ),
    );
  }

  void resetElapsed() {
    _emit(state.copyWith(elapsed: Duration.zero));
  }

  void retryAfterError() {
    _emit(
      state.copyWith(
        errorMessage: null,
        lifecycle: UiPlaybackLifecycle.idle,
        livePulseActive: false,
        liveSyncEligible: true,
      ),
    );
  }

  void toggleLivePulse() {
    if (!state.isEnDirect) return;
    _emit(state.copyWith(livePulseActive: !state.livePulseActive));
  }
}
