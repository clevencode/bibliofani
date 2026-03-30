import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/platform/android_post_notifications.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/core/network/network_connectivity_provider.dart';
import 'package:meu_app/features/radio/radio_audio_player_factory.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';

/// Estado da UI do leitor + reprodução real ([AudioPlayer] + stream).
@immutable
class RadioPlayerUiState {
  const RadioPlayerUiState({
    required this.lifecycle,
    required this.isLiveMode,
    required this.livePulseActive,
    required this.liveSyncEligible,
    this.liveReloadInFlight = false,
    this.errorMessage,
  });

  factory RadioPlayerUiState.initial() => const RadioPlayerUiState(
    lifecycle: UiPlaybackLifecycle.idle,
    isLiveMode: false,
    livePulseActive: false,
    liveSyncEligible: true,
    liveReloadInFlight: false,
    errorMessage: null,
  );

  final UiPlaybackLifecycle lifecycle;
  final bool isLiveMode;
  final bool livePulseActive;

  /// Após pausa fica true até o próximo [liveTap] (marca de sessão; UI / fluxo).
  final bool liveSyncEligible;

  /// Religar ao direto em curso — alinha spinner/estado ao TuneIn.
  final bool liveReloadInFlight;
  final String? errorMessage;

  bool get isPlaying => lifecycle == UiPlaybackLifecycle.playing;

  /// Direct: só o botão «live» activa [isLiveMode]; play/pause fica em écoute.
  /// - [idle]: permite iniciar já em direto (ligação ao fluxo com cache-bust).
  /// - [paused]: permite tocar em «live» para entrar em direct ou catch-up.
  /// - [playing] sem live: permite passar a modo live.
  /// - [playing] com live a tocar: não (já em direct).
  bool get canTapLive =>
      !liveReloadInFlight && radioUiCanTapLive(lifecycle, isLiveMode);

  /// «En direct»: a tocar, sem buffer, com modo live.
  bool get isEnDirect => radioUiIsEnDirect(lifecycle, isLiveMode);

  /// O contador só avança em reprodução efectiva (não durante load/buffer).
  bool get shouldRunElapsedTicker =>
      isPlaying && !isTransportLoadingUiLifecycle(lifecycle);

  RadioPlayerUiState copyWith({
    UiPlaybackLifecycle? lifecycle,
    bool? isLiveMode,
    bool? livePulseActive,
    bool? liveSyncEligible,
    bool? liveReloadInFlight,
    Object? errorMessage = _sentinel,
  }) {
    return RadioPlayerUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      livePulseActive: livePulseActive ?? this.livePulseActive,
      liveSyncEligible: liveSyncEligible ?? this.liveSyncEligible,
      liveReloadInFlight: liveReloadInFlight ?? this.liveReloadInFlight,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _sentinel = Object();
}

final radioPlayerUiProvider =
    StateNotifierProvider<RadioPlayerUiNotifier, RadioPlayerUiState>((ref) {
      final notifier = RadioPlayerUiNotifier(ref);
      // Perda de interface (ex.: Wi‑Fi desliga e não há outra — [offline]): modo refresh + tentativa
      // automática ao voltar online. Wi‑Fi → dados móveis não passa por [offline], a leitura continua.
      ref.listen<RadioNetworkLink>(networkLinkProvider, (previous, next) {
        if (previous == null) return;
        if (next != RadioNetworkLink.offline) return;
        if (previous == RadioNetworkLink.offline) return;
        unawaited(notifier.pauseDueToNetworkLoss());
      });
      return notifier;
    });

/// Regras de negócio da UI + `just_audio` / notificação em segundo plano.
///
/// **Responsabilidades (botões / entradas públicas):**
/// - [transportTap] — só o controlo **play/pause** e anular carregamento em buffer;
///   não activa «en direct».
/// - [liveTap] — só o botão **live** (e «Direto» na notificação Android via
///   [BibleFmMediaNotificationLiveBridge]): modo direct, *catch-up* e nova ligação ao fluxo.
/// - [retryAfterError], [retryErrorBanner], [recoverPlaybackSoft], [pauseDueToNetworkLoss],
///   [onConnectivityRestored] — reacções de sistema / rede, não são botões de transporte.
/// - Interrupções de áudio ([AudioSession.interruptionEventStream]): chamada,
///   alarme, etc. — pausa alinhada à UI; retoma só se esta camada pausou ([_pausedForAudioInterruption]).
///
/// **Fluxo de carregamento:** [transportTap] em [idle] faz *optimistic* [preparing];
/// as fases reais vêm de [AudioPlayer] via [_onPlayerState]. Anular o load (toque em
/// transporte durante [preparing]/[buffering]) chama [_cancelActiveTransportLoad],
/// que faz [stop], invalida a fonte em cache e volta a [idle].
class RadioPlayerUiNotifier extends StateNotifier<RadioPlayerUiState> {
  RadioPlayerUiNotifier(this._ref) : super(RadioPlayerUiState.initial()) {
    BibleFmMediaNotificationLiveBridge.register(this, liveTap);
    if (!kIsWeb) {
      _ensurePlayerAttached();
      unawaited(_subscribeAudioInterruptions());
    }
  }

  final Ref _ref;
  bool get _isOffline => _ref.read(networkOfflineProvider);

  /// Web: sem [AudioPlayer] até ao primeiro play/live — evita carregamento ao abrir.
  void _ensurePlayerAttached() {
    if (_player != null) return;
    _player = createRadioAudioPlayer();
    _playerStateSub = _player!.playerStateStream.listen(
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

  /// Mensagem quando [pauseDueToNetworkLoss] actua (banner + ícone refresh na UI).
  static const String kConnectivityLostMessage = kBibleFmConnectivityLost;

  static const String _kConnectivityLostMessage = kConnectivityLostMessage;

  /// Pausa curta antes da retoma automática (handoff Wi‑Fi/dados, DHCP, etc.).
  static const Duration _kAutoResumeAfterOnlineDelay = Duration(
    milliseconds: 220,
  );

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  /// `true` se a última pausa veio de interrupção do sistema (ex.: chamada);
  /// usado para retomar só quando o SO devolver foco com [pause]/[duck].
  bool _pausedForAudioInterruption = false;

  Timer? _elapsedTicker;

  /// Tempo de escuta acumulado (ticks só em reprodução).
  Duration _liveCatchUpElapsed = Duration.zero;

  /// Início da última pausa (relógio de parede) — para salto «TuneIn» ao tocar em live.
  DateTime? _pausedAtWallClock;

  /// Tempo ouvido nesta sessão; em pausa não avança; [liveTap] em pausa soma o tempo parado de uma vez.
  Duration get sessionListenElapsed => _liveCatchUpElapsed;
  bool _sourceLoaded = false;

  /// Evita que o stream reconcile `idle` antes de `setAudioSource` avançar (race com «preparing»).
  bool _deferPlayerIdle = false;

  /// Evita arranques concorrentes idle→play (duplo toque / reentradas na web).
  bool _playbackStartInFlight = false;

  /// Perda de rede durante reprodução ou carregamento: ao voltar online, retoma sozinha.
  bool _shouldAutoResumeWhenOnline = false;

  bool _disposed = false;

  /// Evita `updateMediaItem` redundante na sessão de média (menos trabalho no SO).
  String? _lastPushedNotificationSignature;

  @override
  void dispose() {
    _disposed = true;
    BibleFmMediaNotificationLiveBridge.unregister(this);
    _elapsedTicker?.cancel();
    unawaited(_interruptionSub?.cancel() ?? Future<void>.value());
    unawaited(_playerStateSub?.cancel() ?? Future<void>.value());
    if (_player != null) {
      unawaited(_player!.dispose());
    }
    super.dispose();
  }

  void _emit(RadioPlayerUiState next) {
    _notePauseWallClock(state.lifecycle, next.lifecycle);
    state = next;
    _syncElapsedTicker();
    _syncNotificationMediaItemIfLoaded();
  }

  void _notePauseWallClock(UiPlaybackLifecycle prev, UiPlaybackLifecycle next) {
    if (next == UiPlaybackLifecycle.paused &&
        prev == UiPlaybackLifecycle.playing) {
      _pausedAtWallClock ??= DateTime.now();
    }
    if (next == UiPlaybackLifecycle.playing) {
      _pausedAtWallClock = null;
    }
  }

  MediaItem _notificationMediaItem(RadioPlayerUiState s) {
    final line = bibleFmMediaNotificationStatusLine(
      lifecycle: s.lifecycle,
      isLiveMode: s.isLiveMode,
    );
    return MediaItem(
      id: kBibleFmMediaItemId,
      title: kBibleFmNotificationTitle,
      album: kBibleFmNotificationAlbum,
      displayTitle: kBibleFmNotificationTitle,
      artist: line,
      displaySubtitle: line,
      displayDescription: kBibleFmNotificationDescription,
      genre: kBibleFmMediaGenre,
      duration: null,
      playable: true,
      // Badge «live» / hint de stream ao vivo: só quando a UI está em «en direct».
      isLive: s.isEnDirect,
    );
  }

  /// Assinatura estável do que a notificação mostra (evita pushes duplicados).
  String _notificationMetadataSignature(RadioPlayerUiState s) =>
      '${s.lifecycle.index}|${s.isLiveMode}|${s.isEnDirect}';

  void _invalidateNotificationMetadataSignature() {
    _lastPushedNotificationSignature = null;
  }

  void _markSourceUnloaded() {
    _sourceLoaded = false;
    _invalidateNotificationMetadataSignature();
  }

  void _syncNotificationMediaItemIfLoaded() {
    if (kIsWeb) return;
    if (!_sourceLoaded || _disposed) return;
    final sig = _notificationMetadataSignature(state);
    if (sig == _lastPushedNotificationSignature) return;
    unawaited(_pushNotificationMediaItemToPlatform(sig));
  }

  Future<void> _pushNotificationMediaItemToPlatform(
    String expectedSignature,
  ) async {
    final snapshot = state;
    if (_disposed || !_sourceLoaded) return;
    if (_notificationMetadataSignature(snapshot) != expectedSignature) return;
    try {
      await JustAudioBackground.updateNowPlayingMediaItem(
        _notificationMediaItem(snapshot),
      );
      if (_disposed) return;
      if (_notificationMetadataSignature(state) != expectedSignature) return;
      _lastPushedNotificationSignature = expectedSignature;
    } catch (e, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'radio_player_ui_provider',
          context: ErrorDescription(
            'Falha ao actualizar metadados na notificação de média',
          ),
        ),
      );
    }
  }

  /// Apresentação **écoute** (sem «en direct»): só altera flags de UI do modo live.
  /// O [AudioPlayer] é tratado à parte pelo chamador ([transportTap], rede, etc.).
  RadioPlayerUiState _ecouteLivePresentation(RadioPlayerUiState s) {
    return s.copyWith(
      isLiveMode: false,
      livePulseActive: false,
      liveSyncEligible: true,
      liveReloadInFlight: false,
    );
  }

  /// Interrompe load/buffer activo: [stop], marca fonte como não carregada, UI em [idle] écoute.
  /// Responsabilidade única para cancelar carregamento (transporte ou rede em load).
  Future<void> _cancelActiveTransportLoad() async {
    _pausedForAudioInterruption = false;
    _deferPlayerIdle = false;
    _playbackStartInFlight = false;
    try {
      await _player?.stop();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('_cancelActiveTransportLoad stop: $e\n$stack');
      }
    }
    _markSourceUnloaded();
    _emit(
      _ecouteLivePresentation(
        state,
      ).copyWith(lifecycle: UiPlaybackLifecycle.idle, errorMessage: null),
    );
  }

  Future<void> _subscribeAudioInterruptions() async {
    try {
      final session = await AudioSession.instance;
      _interruptionSub = session.interruptionEventStream.listen(
        _onAudioInterruptionEvent,
        onError: (Object e, StackTrace st) {
          if (kDebugMode) {
            debugPrint('interruptionEventStream: $e\n$st');
          }
        },
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('_subscribeAudioInterruptions: $e\n$stack');
      }
    }
  }

  void _onAudioInterruptionEvent(AudioInterruptionEvent event) {
    if (event.begin) {
      unawaited(_onAudioInterruptionBegan());
    } else {
      unawaited(_onAudioInterruptionEnded(event.type));
    }
  }

  /// Chamada / alarme / outro foco: pausa o leitor e alinha a UI (como perda de foco, não como erro de rede).
  Future<void> _onAudioInterruptionBegan() async {
    if (!state.isPlaying && !isTransportLoadingUiLifecycle(state.lifecycle)) {
      return;
    }
    try {
      await _player!.pause();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('_onAudioInterruptionBegan pause: $e\n$stack');
      }
    }
    _pausedForAudioInterruption = true;
    _emit(
      _ecouteLivePresentation(
        state,
      ).copyWith(lifecycle: _uiLifecycleFromPlayer(_player!.playerState)),
    );
  }

  /// Fim da interrupção: retoma só se foi esta camada que pausou e o SO indica retomação.
  Future<void> _onAudioInterruptionEnded(AudioInterruptionType type) async {
    if (!_pausedForAudioInterruption) return;
    switch (type) {
      case AudioInterruptionType.pause:
      case AudioInterruptionType.duck:
        _pausedForAudioInterruption = false;
        if (_isOffline) return;
        if (state.errorMessage != null) return;
        try {
          await _player!.play();
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('_onAudioInterruptionEnded play: $e\n$stack');
          }
        }
        break;
      case AudioInterruptionType.unknown:
        _pausedForAudioInterruption = false;
        break;
    }
  }

  static UiPlaybackLifecycle _uiLifecycleFromPlayer(PlayerState playerState) {
    final ps = playerState.processingState;
    final playing = playerState.playing;
    // Live / HTML5: o motor pode reportar loading ou buffering enquanto o áudio
    // já está a reproduzir. A UI do transporte deve seguir [playing], senão o
    // botão fica eternamente em «carregar» com som audível.
    if (playing &&
        ps != ProcessingState.idle &&
        ps != ProcessingState.completed) {
      return UiPlaybackLifecycle.playing;
    }
    switch (ps) {
      case ProcessingState.idle:
        return UiPlaybackLifecycle.idle;
      case ProcessingState.loading:
        return UiPlaybackLifecycle.preparing;
      case ProcessingState.buffering:
        return UiPlaybackLifecycle.buffering;
      case ProcessingState.ready:
        return UiPlaybackLifecycle.paused;
      case ProcessingState.completed:
        return UiPlaybackLifecycle.idle;
    }
  }

  /// Sincroniza [UiPlaybackLifecycle] com [AudioPlayer] (fonte de verdade em reprodução).
  void _onPlayerState(PlayerState playerState) {
    if (_deferPlayerIdle &&
        playerState.processingState == ProcessingState.idle) {
      return;
    }
    if (playerState.processingState != ProcessingState.idle) {
      _deferPlayerIdle = false;
    }

    var nextLifecycle = _uiLifecycleFromPlayer(playerState);

    // Após pausa manual, live/HTML5 pode manter loading|buffering com playing=false;
    // sem isto o stream sobrescrevia [paused] e o transporte ficava em spinner.
    // Durante religação «live» ou arranque idle→play, não interferir.
    if (!playerState.playing &&
        state.lifecycle == UiPlaybackLifecycle.paused &&
        !state.liveReloadInFlight &&
        !_playbackStartInFlight &&
        (nextLifecycle == UiPlaybackLifecycle.buffering ||
            nextLifecycle == UiPlaybackLifecycle.preparing)) {
      nextLifecycle = UiPlaybackLifecycle.paused;
    }

    // Offline com erro visível: não adoptar load/play do player (evita barra de
    // progresso / «a tocar» após [stop] na perda de rede ou rebotes do stream).
    if (_isOffline && state.errorMessage != null) {
      switch (nextLifecycle) {
        case UiPlaybackLifecycle.preparing:
        case UiPlaybackLifecycle.buffering:
        case UiPlaybackLifecycle.playing:
          return;
        case UiPlaybackLifecycle.idle:
        case UiPlaybackLifecycle.paused:
          break;
      }
    }

    if (nextLifecycle != state.lifecycle) {
      _notePauseWallClock(state.lifecycle, nextLifecycle);
      state = state.copyWith(lifecycle: nextLifecycle);
      if (nextLifecycle == UiPlaybackLifecycle.playing) {
        _playbackStartInFlight = false;
      }
      _syncElapsedTicker();
      _syncNotificationMediaItemIfLoaded();
    }
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
      if (!state.shouldRunElapsedTicker) return;
      _liveCatchUpElapsed += const Duration(seconds: 1);
    });
  }

  void _stopElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

  /// Salto estilo TuneIn: soma de uma vez o tempo em pausa ao contador (não conta segundo a segundo em pausa).
  void _applyLiveElapsedJumpFromPausedWallClock() {
    if (state.lifecycle != UiPlaybackLifecycle.paused) return;
    final mark = _pausedAtWallClock;
    if (mark == null) return;
    _liveCatchUpElapsed += DateTime.now().difference(mark);
    _pausedAtWallClock = null;
  }

  /// Nova ligação HTTP ao mesmo endpoint (query única) para saltar o buffer acumulado
  /// e ouvir o instante actual do Icecast — boa prática em streams sem seek.
  AudioSource _liveSource({bool bustCache = false}) {
    var uri = Uri.parse(kBibleFmLiveStreamUrl);
    if (bustCache) {
      final q = Map<String, String>.from(uri.queryParameters);
      q['_'] = DateTime.now().millisecondsSinceEpoch.toString();
      uri = uri.replace(queryParameters: q);
    }
    return AudioSource.uri(uri, tag: _notificationMediaItem(state));
  }

  Future<void> _ensureSourceLoaded() async {
    if (_sourceLoaded) return;
    try {
      await _player!.setAudioSource(_liveSource(bustCache: false));
      _sourceLoaded = true;
      _invalidateNotificationMetadataSignature();
      _syncNotificationMediaItemIfLoaded();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('RadioPlayerUiNotifier: setAudioSource failed: $e\n$stack');
      }
      rethrow;
    }
  }

  static String _loadErrorMessage(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (kIsWeb) {
      if (lower.contains('notallowed') ||
          lower.contains('not allowed') ||
          lower.contains('permission denied') ||
          lower.contains('user gesture') ||
          lower.contains('play() request was interrupted')) {
        return kBibleFmErrorWebPlayback;
      }
      if (lower.contains('cors') ||
          lower.contains('cross-origin') ||
          lower.contains('crossorigin') ||
          lower.contains('media_err_src_not_supported') ||
          lower.contains('networkerror') && lower.contains('media')) {
        return kBibleFmErrorStream;
      }
    }
    if (lower.contains('source error')) {
      return kBibleFmErrorStream;
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset')) {
      return kBibleFmErrorUnreachable;
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return kBibleFmErrorTimeout;
    }
    if (lower.contains('certificate') || lower.contains('handshake')) {
      return kBibleFmErrorSecurity;
    }
    if (raw.length > 160) {
      return '${raw.substring(0, 157)}…';
    }
    return raw;
  }

  /// Chamado quando a interface de rede volta (ex.: Wi‑Fi/dados).
  /// Se havia reprodução ou carregamento quando a rede caiu, tenta retomar sozinha;
  /// caso contrário remove **apenas** [kConnectivityLostMessage] (aviso de ausência de rede).
  /// Erros de fluxo após retoma falhada mantêm-se — evita voltar a «En pause» sem modo refresh.
  void onConnectivityRestored() {
    if (_isOffline) return;
    final wantAutoResume = _shouldAutoResumeWhenOnline;
    _shouldAutoResumeWhenOnline = false;

    if (wantAutoResume && !kIsWeb) {
      unawaited(_resumePlaybackAfterConnectivityRestored());
      return;
    }

    if (state.errorMessage == kConnectivityLostMessage &&
        (state.lifecycle == UiPlaybackLifecycle.idle ||
            state.lifecycle == UiPlaybackLifecycle.paused)) {
      _emit(state.copyWith(errorMessage: null));
    }
  }

  /// Transição **online → offline** (ex.: Wi‑Fi cai e não há fallback de dados).
  /// Não reutiliza [transportTap] (evita misturar com dismiss de erro).
  ///
  /// - **A tocar:** [stop] (modo refresh, não chip «pausa»), [idle] + mensagem;
  ///   marca retoma automática ao voltar online.
  /// - **Load activo:** [_cancelActiveTransportLoad] + mensagem; retoma automática.
  /// - **[idle] / [paused]:** mensagem de rede (substitui erros antigos para UX coerente
  ///   durante a ausência de rede; sem retoma automática).
  Future<void> pauseDueToNetworkLoss() async {
    _pausedForAudioInterruption = false;
    switch (state.lifecycle) {
      case UiPlaybackLifecycle.idle:
      case UiPlaybackLifecycle.paused:
        _emit(state.copyWith(errorMessage: _kConnectivityLostMessage));
        return;
      case UiPlaybackLifecycle.preparing:
      case UiPlaybackLifecycle.buffering:
        _shouldAutoResumeWhenOnline = true;
        await _cancelActiveTransportLoad();
        _emit(state.copyWith(errorMessage: _kConnectivityLostMessage));
        return;
      case UiPlaybackLifecycle.playing:
        _shouldAutoResumeWhenOnline = true;
        _playbackStartInFlight = false;
        try {
          await _player?.stop();
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('pauseDueToNetworkLoss stop: $e\n$stack');
          }
        }
        _markSourceUnloaded();
        _deferPlayerIdle = false;
        _emit(
          _ecouteLivePresentation(state).copyWith(
            lifecycle: UiPlaybackLifecycle.idle,
            errorMessage: _kConnectivityLostMessage,
          ),
        );
        return;
    }
  }

  /// Após [onConnectivityRestored] quando havia leitura ou buffer activo antes do offline.
  Future<void> _resumePlaybackAfterConnectivityRestored() async {
    if (_isOffline) return;
    await Future<void>.delayed(_kAutoResumeAfterOnlineDelay);
    if (_isOffline) return;
    await _retryAfterErrorAsync();
    if (_isOffline) return;
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    try {
      await transportTap();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('_resumePlaybackAfterConnectivityRestored: $e\n$stack');
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'radio_player_ui_provider',
          context: ErrorDescription('_resumePlaybackAfterConnectivityRestored'),
        ),
      );
      if (state.errorMessage == null &&
          (state.lifecycle == UiPlaybackLifecycle.idle ||
              state.lifecycle == UiPlaybackLifecycle.paused)) {
        _emit(
          _ecouteLivePresentation(
            state,
          ).copyWith(errorMessage: _loadErrorMessage(e)),
        );
      }
    }
  }

  /// Botão refresh (online): repõe estado e volta a ligar o fluxo sem reiniciar o processo.
  Future<void> recoverPlaybackSoft() async {
    if (_isOffline) return;
    await _retryAfterErrorAsync();
    if (_isOffline) return;
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    try {
      await transportTap();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('recoverPlaybackSoft: $e\n$stack');
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'radio_player_ui_provider',
          context: ErrorDescription('recoverPlaybackSoft'),
        ),
      );
      if (state.errorMessage == null &&
          (state.lifecycle == UiPlaybackLifecycle.idle ||
              state.lifecycle == UiPlaybackLifecycle.paused)) {
        _emit(
          _ecouteLivePresentation(
            state,
          ).copyWith(errorMessage: _loadErrorMessage(e)),
        );
      }
    }
  }

  /// Banner «RÉESSAYER»: offline só repõe estado; online repõe e tenta play.
  Future<void> retryErrorBanner() async {
    if (_isOffline) {
      await _retryAfterErrorAsync();
      return;
    }
    await recoverPlaybackSoft();
  }

  /// Arranque da app: inicia a reprodução em **écoute** (sem «en direct» até tocar em live).
  /// Web: sem auto-play — só transporte / actualizar.
  Future<void> autoStartLivePlayback() async {
    if (kIsWeb) return;
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    if (state.errorMessage != null) {
      _emit(state.copyWith(errorMessage: null));
    }
    try {
      await transportTap();
    } catch (e, stack) {
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

  Future<void> _ensureAndroidNotificationsBeforePlayback() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await ensureAndroidPostNotificationsPermission();
  }

  /// Botão **play/pause** (e cancelar buffer): transporte de leitura apenas.
  Future<void> transportTap() async {
    if (state.errorMessage != null) {
      _emit(state.copyWith(errorMessage: null));
      return;
    }

    if (_isOffline) {
      switch (state.lifecycle) {
        case UiPlaybackLifecycle.idle:
        case UiPlaybackLifecycle.paused:
          return;
        case UiPlaybackLifecycle.playing:
        case UiPlaybackLifecycle.preparing:
        case UiPlaybackLifecycle.buffering:
          break;
      }
    }

    _ensurePlayerAttached();

    switch (state.lifecycle) {
      case UiPlaybackLifecycle.preparing:
      case UiPlaybackLifecycle.buffering:
        await _cancelActiveTransportLoad();
        return;

      case UiPlaybackLifecycle.playing:
        _pausedForAudioInterruption = false;
        try {
          await _player!.pause();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('pause: $e\n$stack');
        }
        // Sincronizar já a UI: na web o player pode atrasar o stream de estado.
        _emit(
          _ecouteLivePresentation(
            state,
          ).copyWith(lifecycle: UiPlaybackLifecycle.paused),
        );
        return;

      case UiPlaybackLifecycle.paused:
        _pausedForAudioInterruption = false;
        await _ensureAndroidNotificationsBeforePlayback();
        try {
          await _player!.play();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('play: $e\n$stack');
          _emit(
            _ecouteLivePresentation(
              state,
            ).copyWith(lifecycle: UiPlaybackLifecycle.paused),
          );
          return;
        }
        _emit(
          _ecouteLivePresentation(
            state,
          ).copyWith(lifecycle: UiPlaybackLifecycle.playing),
        );
        return;

      case UiPlaybackLifecycle.idle:
        await _ensureAndroidNotificationsBeforePlayback();
        if (_playbackStartInFlight) return;
        _playbackStartInFlight = true;
        _deferPlayerIdle = true;
        _liveCatchUpElapsed = Duration.zero;
        _pausedAtWallClock = null;
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.preparing,
            liveSyncEligible: true,
            isLiveMode: false,
            livePulseActive: false,
            errorMessage: null,
          ),
        );
        try {
          await _ensureSourceLoaded();
          await _player!.play();
          // Libertar reentrada mesmo se o stream demorar a reportar «playing» (ex.: web).
          _playbackStartInFlight = false;
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('Radio start failed: $e\n$stack');
          }
          _playbackStartInFlight = false;
          _deferPlayerIdle = false;
          _markSourceUnloaded();
          _emit(
            _ecouteLivePresentation(state).copyWith(
              lifecycle: UiPlaybackLifecycle.idle,
              errorMessage: _loadErrorMessage(e),
            ),
          );
        }
        return;
    }
  }

  /// Botão **live**: salto do contador pelo tempo em pausa + religação ao directo.
  void liveTap() {
    if (_isOffline) return;
    if (!state.canTapLive) return;
    _ensurePlayerAttached();
    final wasIdle = state.lifecycle == UiPlaybackLifecycle.idle;
    _applyLiveElapsedJumpFromPausedWallClock();
    if (wasIdle) {
      _deferPlayerIdle = true;
      _emit(
        state.copyWith(
          liveReloadInFlight: true,
          isLiveMode: true,
          errorMessage: null,
          liveSyncEligible: false,
          lifecycle: UiPlaybackLifecycle.preparing,
        ),
      );
    } else {
      _emit(
        state.copyWith(
          liveReloadInFlight: true,
          isLiveMode: true,
          errorMessage: null,
          liveSyncEligible: false,
        ),
      );
    }
    unawaited(_reloadLiveStreamToCurrentEdge());
  }

  /// Só para [liveTap]: [stop] + nova fonte (cache-bust) + [play] — borda ao vivo.
  Future<void> _reloadLiveStreamToCurrentEdge() async {
    _deferPlayerIdle = true;
    try {
      try {
        await _player!.stop();
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('reloadLive stop: $e\n$stack');
        }
      }
      await _player!.setAudioSource(_liveSource(bustCache: true));
      _sourceLoaded = true;
      _invalidateNotificationMetadataSignature();
      _syncNotificationMediaItemIfLoaded();
      await _ensureAndroidNotificationsBeforePlayback();
      await _player!.play();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('reloadLiveStreamToCurrentEdge: $e\n$stack');
      }
      _pausedForAudioInterruption = false;
      _deferPlayerIdle = false;
      _markSourceUnloaded();
      _emit(
        _ecouteLivePresentation(state).copyWith(
          liveReloadInFlight: false,
          lifecycle: UiPlaybackLifecycle.idle,
          errorMessage: _loadErrorMessage(e),
        ),
      );
    } finally {
      _emit(state.copyWith(liveReloadInFlight: false));
    }
  }

  void resetElapsed() {
    _liveCatchUpElapsed = Duration.zero;
    _pausedAtWallClock = null;
  }

  void retryAfterError() {
    unawaited(_retryAfterErrorAsync());
  }

  Future<void> _retryAfterErrorAsync() async {
    _shouldAutoResumeWhenOnline = false;
    _playbackStartInFlight = false;
    try {
      await _player?.stop();
    } catch (_) {}
    _pausedForAudioInterruption = false;
    _deferPlayerIdle = false;
    _markSourceUnloaded();
    _liveCatchUpElapsed = Duration.zero;
    _pausedAtWallClock = null;
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
