import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/core/errors/playback_error_mapper.dart';
import 'package:meu_app/core/network/connectivity_providers.dart';
import 'package:meu_app/core/platform/android_ui_task_lifecycle.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';

/// Estado da UI do leitor + reprodução real ([AudioPlayer] + stream).
///
/// **Camadas**
/// - **Entrada:** [autoStartLivePlayback], [centralTap], [liveTap], [retryAfterError].
/// - **Processamento:** este notifier + eventos do [AudioPlayer] → [RadioPlayerUiState].
/// - **Saída:** widgets leem o estado (som e notificação vêm do just_audio em paralelo).
@immutable
class RadioPlayerUiState {
  const RadioPlayerUiState({
    required this.lifecycle,
    required this.elapsed,
    required this.isLiveMode,
    required this.livePulseActive,
    required this.liveSyncEligible,
    this.errorMessage,
    this.errorKind,
  });

  factory RadioPlayerUiState.initial() => const RadioPlayerUiState(
        lifecycle: UiPlaybackLifecycle.idle,
        elapsed: Duration.zero,
        isLiveMode: false,
        livePulseActive: false,
        liveSyncEligible: true,
        errorMessage: null,
        errorKind: null,
      );

  final UiPlaybackLifecycle lifecycle;
  final Duration elapsed;
  final bool isLiveMode;
  final bool livePulseActive;
  /// Após uma pausa, permite alinhar o contador ao direct; consome-se ao tocar em live até nova pausa.
  final bool liveSyncEligible;
  final String? errorMessage;
  /// Classificação do último erro de reprodução (null se não há erro).
  final PlaybackErrorKind? errorKind;

  bool get isPlaying => lifecycle == UiPlaybackLifecycle.playing;

  /// Há sessão com fonte (a tocar ou em pausa), fora da fase de ligação — o botão live pode agir.
  bool get canTapLive =>
      !isConnectingLifecycle(lifecycle) &&
      (lifecycle == UiPlaybackLifecycle.playing ||
          lifecycle == UiPlaybackLifecycle.paused);

  /// «En direct»: a tocar, sem ligação/buffer pendente, com modo live.
  bool get isEnDirect =>
      isPlaying && !isConnectingLifecycle(lifecycle) && isLiveMode;

  /// O contador só avança em reprodução efectiva (não durante ligação/buffer).
  bool get shouldRunElapsedTicker =>
      isPlaying && !isConnectingLifecycle(lifecycle);

  RadioPlayerUiState copyWith({
    UiPlaybackLifecycle? lifecycle,
    Duration? elapsed,
    bool? isLiveMode,
    bool? livePulseActive,
    bool? liveSyncEligible,
    Object? errorMessage = _sentinel,
    Object? errorKind = _sentinel2,
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
      errorKind: identical(errorKind, _sentinel2)
          ? this.errorKind
          : errorKind as PlaybackErrorKind?,
    );
  }

  static const Object _sentinel = Object();
  static const Object _sentinel2 = Object();
}

/// Estado global do leitor (ecrã único): mantido vivo com o `ProviderScope` da app — sem `autoDispose`
/// para o [AudioPlayer] não ser recriado ao reconstruir a árvore.
final radioPlayerUiProvider =
    StateNotifierProvider<RadioPlayerUiNotifier, RadioPlayerUiState>((ref) {
  return RadioPlayerUiNotifier(ref);
});

/// Regras de negócio da UI + `just_audio` / notificação em segundo plano.
///
/// **Transporte (responsabilidades separadas)**
/// - Botão **play** / **pausa** central ([centralTap]): em `playing` usa [AudioPlayer.pause]
///   (mantém o buffer — retoma onde parou); em `paused` ou `idle`, [play] / arranque sem reconectar por si.
/// - Botão **live** ([liveTap]): único caminho que **volta a ligar o stream ao instante em directo**
///   (reconexão) quando estás em diferido ou em pausa; com sessão já em directo, só afinar o contador na UI.
class RadioPlayerUiNotifier extends StateNotifier<RadioPlayerUiState> {
  RadioPlayerUiNotifier(this._ref) : super(RadioPlayerUiState.initial()) {
    _player = AudioPlayer();
    _playerStateSub = _player.playerStateStream.listen(
      _onPlayerState,
      onError: _onPlayerStateError,
    );
    registerAndroidUiTaskRemovedCallback(_onAndroidUiTaskFinishing);
    _ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityResultsProvider,
      (prev, next) => _onConnectivitySnapshot(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;

  /// Remove das recentes / fecho da activity: parar stream e estado inicial (próxima abertura = arranque limpo).
  void _onAndroidUiTaskFinishing() {
    unawaited(_releasePlaybackForAndroidUiTaskRemoved());
  }

  Future<void> _releasePlaybackForAndroidUiTaskRemoved() async {
    _invalidatePlaybackEpoch();
    try {
      await _player.stop();
    } catch (_) {}
    _deferPlayerIdle = false;
    _cancelAutoLivePending();
    _sourceLoaded = false;
    _emit(RadioPlayerUiState.initial());
  }

  void _onConnectivitySnapshot(AsyncValue<List<ConnectivityResult>> next) {
    next.whenData((results) {
      if (networkResultsAllowPlayback(results)) {
        _handleConnectivityRestored();
      } else {
        unawaited(_handleConnectivityLost());
      }
    });
  }

  /// Perda de interface enquanto há sessão de escuta (a tocar, a ligar ou em pausa com buffer).
  Future<void> _handleConnectivityLost() async {
    final life = state.lifecycle;
    if (life != UiPlaybackLifecycle.playing &&
        life != UiPlaybackLifecycle.connecting &&
        life != UiPlaybackLifecycle.paused) {
      return;
    }
    await _stopPlaybackToIdle(
      setErrorMessage: RadioUserMessages.offlinePlayback,
      setErrorKind: PlaybackErrorKind.offline,
    );
  }

  /// Volta a haver interface: limpar aviso de offline se era só por rede.
  void _handleConnectivityRestored() {
    if (state.errorKind == PlaybackErrorKind.offline) {
      _emit(
        state.copyWith(
          errorMessage: null,
          errorKind: null,
        ),
      );
    }
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

  /// Cada toque em “live” aproxima o contador do instante actual (sem saltar tudo de uma vez).
  static const Duration _liveCatchUpChunk = Duration(seconds: 30);

  static const Duration _minElapsedAfterLiveTap = Duration(seconds: 1);

  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSub;

  Timer? _elapsedTicker;
  bool _autoLivePending = false;
  bool _sourceLoaded = false;
  /// Entre um `stop` explícito e o próximo conteúdo a carregar (arranque ou reconexão live).
  bool _deferPlayerIdle = false;

  /// Versão monotónica: [stop] / nova carga invalidam operações de [_startPlaybackFromIdle] e
  /// [play] em voo (race entre duplo toque, cancelar ligação, rede, etc.).
  int _playbackEpoch = 0;

  void _invalidatePlaybackEpoch() {
    _playbackEpoch++;
  }

  bool _isStalePlaybackSession(int session) => session != _playbackEpoch;

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
    registerAndroidUiTaskRemovedCallback(null);
    _elapsedTicker?.cancel();
    unawaited(_playerStateSub?.cancel() ?? Future<void>.value());
    unawaited(_player.dispose());
    super.dispose();
  }

  /// Atualiza estado completo e reacciona (ticker, auto-live pendente).
  void _emit(RadioPlayerUiState next) {
    state = next;
    _syncElapsedTicker();
    _tryApplyPendingAutoLive();
  }

  void _cancelAutoLivePending() {
    _autoLivePending = false;
  }

  /// [AudioPlayer.stop], liberta a fonte (`_sourceLoaded = false`) e UI em `idle`.
  /// Sem [setErrorMessage]: limpa erros. Usado ao cancelar ligação, erros e rede perdida — não pela pausa central.
  Future<void> _stopPlaybackToIdle({
    String? setErrorMessage,
    PlaybackErrorKind? setErrorKind,
  }) async {
    _invalidatePlaybackEpoch();
    _deferPlayerIdle = false;
    _cancelAutoLivePending();
    try {
      await _player.stop();
    } catch (e, stack) {
      if (kDebugMode) debugPrint('stop playback: $e\n$stack');
    }
    _sourceLoaded = false;
    _emit(
      state.copyWith(
        lifecycle: UiPlaybackLifecycle.idle,
        isLiveMode: false,
        livePulseActive: false,
        liveSyncEligible: true,
        errorMessage: setErrorMessage,
        errorKind: setErrorKind,
      ),
    );
  }

  /// Sincroniza [lifecycle] com o [ProcessingState] / `playing` do [AudioPlayer].
  void _setLifecycleFromPlayer(UiPlaybackLifecycle next) {
    if (next == state.lifecycle) return;
    state = state.copyWith(lifecycle: next);
    _syncElapsedTicker();
    _tryApplyPendingAutoLive();
  }

  void _onPlayerState(PlayerState playerState) {
    if (_deferPlayerIdle &&
        playerState.processingState == ProcessingState.idle) {
      // Entre `stop` e novo `loading`: evitar mostrar `idle` — ainda estamos a (re)ligar o stream.
      _setLifecycleFromPlayer(UiPlaybackLifecycle.connecting);
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
      case ProcessingState.buffering:
        nextLifecycle = UiPlaybackLifecycle.connecting;
        break;
      case ProcessingState.ready:
        nextLifecycle =
            playing ? UiPlaybackLifecycle.playing : UiPlaybackLifecycle.paused;
        break;
      case ProcessingState.completed:
        nextLifecycle = UiPlaybackLifecycle.idle;
        break;
    }

    _setLifecycleFromPlayer(nextLifecycle);
  }

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

  /// Depois de play estável, aplica “modo direct” se o arranque automático pediu.
  void _tryApplyPendingAutoLive() {
    if (!_autoLivePending) return;
    if (!state.isPlaying || isConnectingLifecycle(state.lifecycle)) return;
    if (!state.canTapLive) return;
    _autoLivePending = false;
    unawaited(_liveTapAsync(userInitiated: false));
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

  /// Após [_ensureSourceLoaded], dá [play] com verificação de [session] / [_deferPlayerIdle].
  /// Devolve `false` se a operação deve abortar sem mais efeitos (sessão obsoleta).
  Future<bool> _ensureSourceLoadedAndPlay(int session) async {
    await _ensureSourceLoaded();
    if (_isStalePlaybackSession(session)) {
      _deferPlayerIdle = false;
      _sourceLoaded = false;
      try {
        await _player.stop();
      } catch (_) {}
      return false;
    }
    await _player.play();
    if (_isStalePlaybackSession(session)) {
      _deferPlayerIdle = false;
      return false;
    }
    return true;
  }

  /// Arranque da app: play + modo direct quando o áudio estiver estável.
  Future<void> autoStartLivePlayback() async {
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    try {
      if (state.errorMessage != null) {
        await _retryAfterErrorAsync();
      }
      _autoLivePending = true;
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

  /// Primeiro play a partir de [idle] (e após limpar erro no mesmo gesto).
  Future<void> _startPlaybackFromIdle() async {
    if (!_ref.read(hasNetworkProvider)) {
      _deferPlayerIdle = false;
      _cancelAutoLivePending();
      _emit(
        state.copyWith(
          errorMessage: RadioUserMessages.offlinePlayback,
          errorKind: PlaybackErrorKind.offline,
        ),
      );
      return;
    }

    final session = ++_playbackEpoch;
    _deferPlayerIdle = true;
    _emit(
      state.copyWith(
        lifecycle: UiPlaybackLifecycle.connecting,
        elapsed: Duration.zero,
        liveSyncEligible: true,
        isLiveMode: false,
        livePulseActive: false,
        errorMessage: null,
        errorKind: null,
      ),
    );
    try {
      final played = await _ensureSourceLoadedAndPlay(session);
      if (!played) return;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Radio start failed: $e\n$stack');
      }
      if (_isStalePlaybackSession(session)) {
        _deferPlayerIdle = false;
        return;
      }
      _deferPlayerIdle = false;
      _cancelAutoLivePending();
      _sourceLoaded = false;
      final failure = mapPlaybackFailure(e);
      _emit(
        state.copyWith(
          lifecycle: UiPlaybackLifecycle.idle,
          errorMessage: failure.message,
          errorKind: failure.kind,
        ),
      );
    }
  }

  /// Botão central: **play** / retomar, **pausa** (mantém buffer), cancelar **ligação**.
  Future<void> centralTap() async {
    if (state.errorMessage != null) {
      _cancelAutoLivePending();
      await _retryAfterErrorAsync();
      await _startPlaybackFromIdle();
      return;
    }

    switch (state.lifecycle) {
      case UiPlaybackLifecycle.connecting:
        await _stopPlaybackToIdle();
        return;

      case UiPlaybackLifecycle.playing:
        final pauseSession = _playbackEpoch;
        try {
          await _player.pause();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('pause: $e\n$stack');
          if (_isStalePlaybackSession(pauseSession)) return;
          await _stopPlaybackToIdle();
          return;
        }
        if (_isStalePlaybackSession(pauseSession)) return;
        return;

      // Retoma o buffer actual; modo “direct” só via [liveTap] se quiseres nova ligação ao ar.
      case UiPlaybackLifecycle.paused:
        if (!_ref.read(hasNetworkProvider)) {
          _emit(
            state.copyWith(
              errorMessage: RadioUserMessages.offlinePlayback,
              errorKind: PlaybackErrorKind.offline,
            ),
          );
          return;
        }
        final resumeSession = _playbackEpoch;
        try {
          await _player.play();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('play: $e\n$stack');
          if (_isStalePlaybackSession(resumeSession)) return;
          final failure = mapPlaybackFailure(e);
          await _stopPlaybackToIdle(
            setErrorMessage: failure.message,
            setErrorKind: failure.kind,
          );
          return;
        }
        if (_isStalePlaybackSession(resumeSession)) return;
        _emit(
          state.copyWith(
            isLiveMode: false,
            livePulseActive: false,
            liveSyncEligible: true,
          ),
        );
        return;

      case UiPlaybackLifecycle.idle:
        await _startPlaybackFromIdle();
        return;
    }
  }

  /// Botão **live**: modo directo na UI; reconexão ao stream só quando o utilizador toca
  /// ([userInitiated]) — o arranque automático limita-se a alinhar a UI sem novo `setAudioSource`.
  void liveTap() {
    unawaited(_liveTapAsync(userInitiated: true));
  }

  Future<void> _liveTapAsync({required bool userInitiated}) async {
    if (!state.canTapLive) return;

    final bool reconnect = state.lifecycle == UiPlaybackLifecycle.paused ||
        (userInitiated &&
            state.lifecycle == UiPlaybackLifecycle.playing &&
            !state.isLiveMode);

    if (reconnect) {
      if (!_ref.read(hasNetworkProvider)) {
        _emit(
          state.copyWith(
            errorMessage: RadioUserMessages.offlinePlayback,
            errorKind: PlaybackErrorKind.offline,
          ),
        );
        return;
      }
      _cancelAutoLivePending();
      final session = ++_playbackEpoch;
      _deferPlayerIdle = true;
      _emit(
        state.copyWith(
          lifecycle: UiPlaybackLifecycle.connecting,
          livePulseActive: false,
          errorMessage: null,
          errorKind: null,
        ),
      );
      try {
        await _player.stop();
        if (_isStalePlaybackSession(session)) {
          _deferPlayerIdle = false;
          return;
        }
        _sourceLoaded = false;
        final played = await _ensureSourceLoadedAndPlay(session);
        if (!played) return;
      } catch (e, stack) {
        _deferPlayerIdle = false;
        if (kDebugMode) debugPrint('liveTap reconnect: $e\n$stack');
        if (_isStalePlaybackSession(session)) return;
        _sourceLoaded = false;
        final failure = mapPlaybackFailure(e);
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.idle,
            isLiveMode: false,
            livePulseActive: false,
            liveSyncEligible: true,
            errorMessage: failure.message,
            errorKind: failure.kind,
          ),
        );
        return;
      }

      _emit(
        state.copyWith(
          isLiveMode: true,
          liveSyncEligible: false,
          elapsed: Duration.zero,
          errorMessage: null,
          errorKind: null,
        ),
      );
      return;
    }

    final s = state;
    final nextElapsed = _elapsedAfterLiveTap(
      s.elapsed,
      consumeSync: true,
    );
    _emit(
      s.copyWith(
        isLiveMode: true,
        errorMessage: null,
        errorKind: null,
        elapsed: nextElapsed,
        liveSyncEligible: false,
      ),
    );
  }

  void resetElapsed() {
    _emit(state.copyWith(elapsed: Duration.zero));
  }

  void retryAfterError() {
    unawaited(_retryAfterErrorAsync());
  }

  Future<void> _retryAfterErrorAsync() async {
    await _stopPlaybackToIdle();
  }

  void toggleLivePulse() {
    if (!state.isEnDirect) return;
    _emit(state.copyWith(livePulseActive: !state.livePulseActive));
  }
}
