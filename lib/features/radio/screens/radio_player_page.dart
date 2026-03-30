import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, Listenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meu_app/core/network/network_connectivity_provider.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/platform/android_post_notifications.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';
import 'package:meu_app/features/radio/providers/radio_player_ui_provider.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/live_pulsing_indicator.dart';
import 'package:meu_app/features/radio/widgets/radio_transport_controls.dart';
import 'package:meu_app/features/radio/widgets/web_native_audio.dart';

/// Bible FM: layout **mobile-first** — base para telemóvel, depois tablet/paisagem.
/// Estrutura alinhada às orientações de **margens, contenção e encartes** do
/// Android ([content structure](https://developer.android.com/design/ui/mobile/guides/layout-and-content/content-structure?hl=pt-br)):
/// grelha 8 pt, ~16 dp lateral em compacto, cartão como contenção explícita,
/// área segura e corpo rolável quando o conteúdo excede a altura.
/// Estado de leitura / indicador de áudio / live: [radioPlayerUiProvider].
///
/// [ConsumerStatefulWidget] para [ref] no arranque automático e no `build`.
class RadioPlayerPage extends ConsumerStatefulWidget {
  const RadioPlayerPage({super.key});

  @override
  ConsumerState<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends ConsumerState<RadioPlayerPage> {
  /// Arranque automático adiado: abriu sem rede e ainda não tocou play.
  bool _deferAutostartUntilOnline = false;

  /// [checkConnectivity] falhou por completo: espera o primeiro estado não-[unknown] no stream.
  bool _pendingAutostartAfterUnknownLink = false;

  ProviderSubscription<RadioNetworkLink>? _networkLinkSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _networkLinkSub = ref.listenManual<RadioNetworkLink>(
        networkLinkProvider,
        _onNetworkLinkChanged,
      );
    }
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_postFrameBootstrap());
    });
  }

  @override
  void dispose() {
    _networkLinkSub?.close();
    super.dispose();
  }

  void _onNetworkLinkChanged(
    RadioNetworkLink? previous,
    RadioNetworkLink next,
  ) {
    if (!kIsWeb &&
        _pendingAutostartAfterUnknownLink &&
        previous == RadioNetworkLink.unknown &&
        next != RadioNetworkLink.unknown) {
      _pendingAutostartAfterUnknownLink = false;
      final radio = ref.read(radioPlayerUiProvider.notifier);
      if (next == RadioNetworkLink.offline) {
        _deferAutostartUntilOnline = true;
      } else {
        unawaited(radio.autoStartLivePlayback());
      }
    }

    final wasOffline = previous == RadioNetworkLink.offline;
    final onlineNow = next != RadioNetworkLink.offline;
    if (wasOffline && onlineNow) {
      final radio = ref.read(radioPlayerUiProvider.notifier);
      radio.onConnectivityRestored();
      if (!kIsWeb && _deferAutostartUntilOnline) {
        _deferAutostartUntilOnline = false;
        unawaited(radio.autoStartLivePlayback());
      }
    }
    if (next == RadioNetworkLink.wifi &&
        previous != null &&
        previous != RadioNetworkLink.wifi &&
        previous != RadioNetworkLink.unknown) {
      HapticFeedback.selectionClick();
    }
  }

  /// Permissão de notificação antes do autostart, com pequeno espaçamento para o diálogo do SO.
  /// Web: sem autostart nem permissões — utilizador usa play ou actualizar.
  Future<void> _postFrameBootstrap() async {
    if (kIsWeb) return;
    await ensureAndroidPostNotificationsPermission();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await _maybeAutoStartAfterConnectivity();
  }

  /// Primeira leitura de rede; offline ou [unknown] persistente adia o autostart de forma explícita.
  Future<void> _maybeAutoStartAfterConnectivity() async {
    if (!mounted) return;
    final net = ref.read(networkLinkProvider.notifier);
    await net.initialConnectivityFuture;
    if (!mounted) return;
    await net.ensureKnownLink();
    if (!mounted) return;

    final link = ref.read(networkLinkProvider);
    if (link == RadioNetworkLink.unknown) {
      _pendingAutostartAfterUnknownLink = true;
      return;
    }

    if (link.isOffline) {
      _deferAutostartUntilOnline = true;
      _pendingAutostartAfterUnknownLink = false;
      return;
    }

    _deferAutostartUntilOnline = false;
    _pendingAutostartAfterUnknownLink = false;
    await ref.read(radioPlayerUiProvider.notifier).autoStartLivePlayback();
  }

  /// Refresh: offline repõe estado do leitor e avisa; online recupera o fluxo sem reiniciar o processo.
  Future<void> _onRefreshPressed() async {
    if (!mounted) return;
    if (ref.read(networkOfflineProvider)) {
      await ref.read(radioPlayerUiProvider.notifier).retryErrorBanner();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Sem ligação. Verifique o Wi‑Fi ou os dados móveis.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref.read(radioPlayerUiProvider.notifier).recoverPlaybackSoft();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final isOffline = ref.watch(networkOfflineProvider);
      const webCapsuleH = 52.0;
      const webPadH = 8.0;
      const webPadV = 5.0;
      const webLiveDiameter = 42.0;
      const webAudioH = 40.0;
      final innerH = webCapsuleH - 2 * webPadV;
      return Semantics(
        container: true,
        label: kBibleFmWebFrSemanticsPlayerPage,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _PageBackground(),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WebRealtimeFeedbackLine(isOffline: isOffline),
                          const SizedBox(height: 16),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.webPlaybackCapsuleOuter,
                              borderRadius: BorderRadius.circular(
                                webCapsuleH / 2,
                              ),
                              border: Border.all(
                                color: AppTheme.webPlaybackCapsuleOuterBorder,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                webPadH,
                                webPadV,
                                webPadH,
                                webPadV,
                              ),
                              child: SizedBox(
                                height: innerH,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ListenableBuilder(
                                      listenable: Listenable.merge([
                                        bibleFmWebPlaybackActive,
                                        bibleFmWebLiveReloading,
                                        bibleFmWebLiveEdgeActive,
                                      ]),
                                      builder: (context, _) {
                                        final playing =
                                            bibleFmWebPlaybackActive.value;
                                        final reloading =
                                            bibleFmWebLiveReloading.value;
                                        final atLiveEdge =
                                            bibleFmWebLiveEdgeActive.value;
                                        final emphasiseLive = playing ||
                                            reloading ||
                                            (playing && atLiveEdge);
                                        return Opacity(
                                          opacity: emphasiseLive ? 1.0 : 0.45,
                                          child: _WebLiveStreamButton(
                                            diameter: webLiveDiameter,
                                            isOffline: isOffline,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: WebNativeAudioControls(
                                        streamUrl: kBibleFmLiveStreamUrl,
                                        controlsHeight: webAudioH,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pageUi = ref.watch(
      radioPlayerUiProvider.select(
        (s) => (
          lifecycle: s.lifecycle,
          isLiveMode: s.isLiveMode,
          livePulseActive: s.livePulseActive,
          liveReloadInFlight: s.liveReloadInFlight,
          errorMessage: s.errorMessage,
        ),
      ),
    );
    final player = ref.read(radioPlayerUiProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = scheme.surfaceContainerHighest;
    final titleColor = scheme.onSurface;

    final isOffline = ref.watch(networkOfflineProvider);

    /// Offline ou qualquer erro: modo refresh (botão e mensagens) em qualquer fase do transporte.
    final needsRecoveryRefresh = isOffline || pageUi.errorMessage != null;
    final showStreamLoading =
        isTransportLoadingUiLifecycle(pageUi.lifecycle) &&
        !needsRecoveryRefresh;

    final isPlaying = pageUi.lifecycle == UiPlaybackLifecycle.playing;
    final isEnDirect = radioUiIsEnDirect(pageUi.lifecycle, pageUi.isLiveMode);
    final canTapLive = radioUiCanTapLive(pageUi.lifecycle, pageUi.isLiveMode);
    final isTransportLoading = isTransportLoadingUiLifecycle(pageUi.lifecycle);

    return Semantics(
      container: true,
      label: kBibleFmSemanticsPlayerPage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _PageBackground(),
            SafeArea(
              child: RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    // Mobile-first: base mobile, depois overrides para tablet/landscape.
                    final isCompact = AppLayoutBreakpoints.isCompactHeight(h);
                    final isNarrow = AppLayoutBreakpoints.isNarrow(w);

                    final scale = AppSpacing.mobileLayoutScale(
                      constraints.biggest.shortestSide,
                    );
                    final sidePadding = AppSpacing.g(
                      AppSpacing.marginContentHorizontalSteps(narrow: isNarrow),
                      scale,
                    );
                    final transportSidePadding = AppSpacing.g(
                      AppSpacing.marginTransportHorizontalSteps(
                        narrow: isNarrow,
                      ),
                      scale,
                    );
                    final panelPaddingH = AppSpacing.g(
                      AppSpacing.marginPanelInnerHorizontalSteps(
                        narrow: isNarrow,
                      ),
                      scale,
                    );
                    final panelWidth = AppLayoutBreakpoints.maxPanelWidth(
                      w,
                      h,
                      scale,
                    );
                    final isPhonePortrait =
                        !AppLayoutBreakpoints.isTablet(w) &&
                        !AppLayoutBreakpoints.isLandscape(w, h);
                    final cardWidthFraction = isPhonePortrait ? 0.96 : 1.0;

                    final playButtonSize = AppSpacing.g(
                      AppSpacing.playControlDiameterSteps(
                        layoutWidth: w,
                        layoutHeight: h,
                      ),
                      scale,
                    );
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    final playVisualSize = playButtonSize.clamp(
                      AppSpacing.g(
                        AppSpacing.playControlDiameterMinSteps,
                        scale,
                      ),
                      AppSpacing.g(
                        AppSpacing.playControlDiameterMaxSteps,
                        scale,
                      ),
                    );
                    final scrollBottomPadding =
                        bottomInset +
                        AppSpacing.g(
                          AppSpacing.transportBottomMarginSteps,
                          scale,
                        );

                    return Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        if (showStreamLoading)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _StreamLoadingStrip(colorScheme: scheme),
                          ),
                        Positioned.fill(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: scrollBottomPadding,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: sidePadding,
                                      vertical: AppSpacing.g(
                                        AppSpacing.sectionVerticalPaddingSteps,
                                        scale,
                                      ),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, innerConstraints) {
                                        final cardDisplayWidth =
                                            AppSpacing.clampCardContentWidth(
                                              contentWidth:
                                                  innerConstraints.maxWidth,
                                              panelCap: panelWidth,
                                              contentWidthFraction:
                                                  cardWidthFraction,
                                            );
                                        return SingleChildScrollView(
                                          clipBehavior: Clip.none,
                                          physics:
                                              const ClampingScrollPhysics(),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight:
                                                  innerConstraints.maxHeight,
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Cartão «sem rede» só se o topo ainda não mostra erro.
                                                  if (isOffline &&
                                                      pageUi.errorMessage ==
                                                          null) ...[
                                                    SizedBox(
                                                      width: cardDisplayWidth,
                                                      child: _OfflineBanner(
                                                        scale: scale,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: AppSpacing.g(
                                                        3,
                                                        scale,
                                                      ),
                                                    ),
                                                  ],
                                                  if (pageUi.errorMessage !=
                                                      null) ...[
                                                    SizedBox(
                                                      width: cardDisplayWidth,
                                                      child: _ErrorBanner(
                                                        scale: scale,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: AppSpacing.g(
                                                        2,
                                                        scale,
                                                      ),
                                                    ),
                                                  ],
                                                  if (!kIsWeb)
                                                    _MainPlayerCard(
                                                      width: cardDisplayWidth,
                                                      panelPaddingH:
                                                          panelPaddingH,
                                                      cardColor: cardColor,
                                                      isDark: isDark,
                                                      scale: scale,
                                                      isCompactHeight:
                                                          isCompact,
                                                      narrowMobile: isNarrow,
                                                      isOffline: isOffline,
                                                      hasRecoverableError:
                                                          pageUi.errorMessage !=
                                                          null,
                                                      isPlaying: isPlaying,
                                                      isBuffering:
                                                          isTransportLoading,
                                                      isLiveMode:
                                                          pageUi.isLiveMode,
                                                      isEnDirect: isEnDirect,
                                                      livePulseActive:
                                                          pageUi
                                                              .livePulseActive &&
                                                          isEnDirect,
                                                      onLiveIndicatorTap:
                                                          isOffline
                                                          ? null
                                                          : isEnDirect
                                                          ? player
                                                                .toggleLivePulse
                                                          : (canTapLive
                                                                ? player.liveTap
                                                                : null),
                                                      titleColor: titleColor,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: transportSidePadding,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: RepaintBoundary(
                                  child: RadioTransportControls(
                                    scale: scale,
                                    playVisualSize: playVisualSize,
                                    isOffline: isOffline,
                                    playbackLifecycle: pageUi.lifecycle,
                                    isPlaying: isPlaying,
                                    isPaused:
                                        pageUi.lifecycle ==
                                        UiPlaybackLifecycle.paused,
                                    isBuffering: isTransportLoading,
                                    isPreparing:
                                        pageUi.lifecycle ==
                                        UiPlaybackLifecycle.preparing,
                                    isLiveMode: pageUi.isLiveMode,
                                    isLiveReloading:
                                        pageUi.liveReloadInFlight,
                                    onTransportTap: () =>
                                        unawaited(player.transportTap()),
                                    onLiveTap: isOffline
                                        ? null
                                        : (canTapLive ? player.liveTap : null),
                                    onOfflineRestartApp: needsRecoveryRefresh
                                        ? () => unawaited(_onRefreshPressed())
                                        : null,
                                    recoveryUiActive: needsRecoveryRefresh,
                                    refreshRestartsEntireApp: isOffline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa fina estática — sem ticker contínuo do [LinearProgressIndicator].
class _StreamLoadingStrip extends StatelessWidget {
  const _StreamLoadingStrip({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: colorScheme.primary.withValues(alpha: 0.88),
        child: const SizedBox(height: 3, width: double.infinity),
      ),
    );
  }
}

/// Direto / religar fluxo — à esquerda da barra nativa (play integrado no `<audio>`).
/// Estados alinhados ao [LiveModeButton] / TuneIn; ouve os mesmos [Listenable] que a pastilha.
String _webPlaybackFeedbackMessage({
  required bool offline,
  required bool reloading,
  required bool playing,
  required bool buffering,
  required bool liveEdge,
  required bool sessionStarted,
}) {
  if (offline) return kBibleFmWebFrFeedbackOffline;
  if (reloading) return kBibleFmWebFrFeedbackReloading;
  if (playing && buffering) return kBibleFmWebFrFeedbackBuffering;
  if (playing && liveEdge) return kBibleFmWebFrFeedbackLive;
  if (playing) return kBibleFmWebFrFeedbackListening;
  if (sessionStarted) return kBibleFmWebFrFeedbackPaused;
  return kBibleFmWebFrFeedbackReady;
}

Color _webPlaybackFeedbackColor(
  BuildContext context, {
  required bool offline,
  required bool playing,
  required bool liveEdge,
  required bool reloading,
  required bool buffering,
  required bool sessionStarted,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (offline) return scheme.error;
  if (playing && liveEdge) {
    return Colors.white;
  }
  if (reloading || (playing && buffering)) {
    return scheme.onSurfaceVariant;
  }
  if (playing) return scheme.onSurface;
  if (sessionStarted) {
    return scheme.onSurface.withValues(alpha: 0.88);
  }
  return scheme.onSurfaceVariant;
}

/// Título web: estado em tempo real + pingo «ON AIR» em directo.
class _WebRealtimeFeedbackLine extends StatelessWidget {
  const _WebRealtimeFeedbackLine({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        bibleFmWebPlaybackActive,
        bibleFmWebLiveReloading,
        bibleFmWebLiveEdgeActive,
        bibleFmWebBuffering,
        bibleFmWebSessionEverStarted,
      ]),
      builder: (context, _) {
        final playing = bibleFmWebPlaybackActive.value;
        final reloading = bibleFmWebLiveReloading.value;
        final liveEdge = bibleFmWebLiveEdgeActive.value;
        final buffering = bibleFmWebBuffering.value;
        final sessionStarted = bibleFmWebSessionEverStarted.value;
        final msg = _webPlaybackFeedbackMessage(
          offline: isOffline,
          reloading: reloading,
          playing: playing,
          buffering: buffering,
          liveEdge: liveEdge,
          sessionStarted: sessionStarted,
        );
        final color = _webPlaybackFeedbackColor(
          context,
          offline: isOffline,
          playing: playing,
          liveEdge: liveEdge,
          reloading: reloading,
          buffering: buffering,
          sessionStarted: sessionStarted,
        );
        final showOnAirDot =
            !isOffline && playing && liveEdge && !reloading;

        return Semantics(
          liveRegion: true,
          label: msg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showOnAirDot) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE53935),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.45),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) {
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        ...previous,
                        ?current,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final pull = Tween<Offset>(
                      begin: const Offset(0, 0.22),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return SlideTransition(
                      position: pull,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    msg,
                    key: ValueKey<String>(msg),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WebLiveStreamButton extends StatelessWidget {
  const _WebLiveStreamButton({
    this.diameter = 44,
    required this.isOffline,
  });

  final double diameter;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconSize = (diameter * 0.42).clamp(16.0, 24.0);
    final iconColor = AppTheme.transportPlayIcon(brightness);
    final broadcastIconColor =
        brightness == Brightness.dark ? Colors.black : iconColor;
    return ListenableBuilder(
      listenable: Listenable.merge([
        bibleFmWebPlaybackActive,
        bibleFmWebLiveReloading,
        bibleFmWebLiveEdgeActive,
      ]),
      builder: (context, _) {
        final playing = bibleFmWebPlaybackActive.value;
        final reloading = bibleFmWebLiveReloading.value;
        final atLiveEdge = bibleFmWebLiveEdgeActive.value;
        final canTap = !isOffline &&
            !reloading &&
            !(playing && atLiveEdge);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        String semanticsLabel;
        String tooltipMsg;
        if (isOffline) {
          semanticsLabel = kBibleFmWebFrLiveA11yOffline;
          tooltipMsg = kBibleFmWebFrLiveTooltipOffline;
        } else if (reloading) {
          semanticsLabel = kBibleFmWebFrLiveA11yReloading;
          tooltipMsg = kBibleFmWebFrLiveTooltipReloading;
        } else if (playing && atLiveEdge) {
          semanticsLabel = kBibleFmWebFrLiveA11yActive;
          tooltipMsg = kBibleFmWebFrLiveTooltipActive;
        } else if (canTap) {
          semanticsLabel = kBibleFmWebFrLiveA11yGoLive;
          tooltipMsg = kBibleFmWebFrLiveTooltipGoLive;
        } else {
          semanticsLabel = kBibleFmWebFrLiveA11yPauseToEnable;
          tooltipMsg = kBibleFmWebFrLiveTooltipPauseToEnable;
        }

        Widget disc = InkWell(
          onTap: canTap
              ? () => unawaited(
                    bibleFmWebReloadLiveStream(kBibleFmLiveStreamUrl),
                  )
              : null,
          customBorder: const CircleBorder(),
          hoverColor: canTap
              ? (isDark
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.12))
              : Colors.transparent,
          splashColor: canTap
              ? (isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.18))
              : Colors.transparent,
          highlightColor: canTap ? null : Colors.transparent,
          child: Ink(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.transportPlayFill(brightness),
            ),
            child: Center(
              child: reloading
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        color: iconColor,
                        backgroundColor: iconColor.withValues(alpha: 0.22),
                      ),
                    )
                  : BroadcastSignalIcon(
                      color: broadcastIconColor,
                      size: iconSize,
                    ),
            ),
          ),
        );

        if (isOffline) {
          disc = Opacity(opacity: 0.65, child: disc);
        }

        return Semantics(
          button: true,
          selected: playing && atLiveEdge,
          enabled: canTap,
          label: semanticsLabel,
          child: Tooltip(
            message: tooltipMsg,
            waitDuration: const Duration(milliseconds: 320),
            child: MouseRegion(
              cursor:
                  canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: Material(color: Colors.transparent, child: disc),
            ),
          ),
        );
      },
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return DecoratedBox(decoration: BoxDecoration(color: scheme.surface));
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.notionLightBackgroundGradient,
      ),
    );
  }
}

class _MainPlayerCard extends StatelessWidget {
  const _MainPlayerCard({
    required this.width,
    required this.panelPaddingH,
    required this.cardColor,
    required this.isDark,
    required this.scale,
    required this.isCompactHeight,
    required this.narrowMobile,
    required this.isOffline,
    required this.hasRecoverableError,
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.isEnDirect,
    required this.livePulseActive,
    required this.onLiveIndicatorTap,
    required this.titleColor,
  });

  final double width;
  final double panelPaddingH;
  final Color cardColor;
  final bool isDark;
  final double scale;
  final bool isCompactHeight;
  final bool narrowMobile;
  final bool isOffline;

  /// Erro visível (banner / modo refresh): não mostrar «En pause» como se fosse pausa manual.
  final bool hasRecoverableError;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final bool isEnDirect;
  final bool livePulseActive;
  final VoidCallback? onLiveIndicatorTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const cornerPt = AppLayoutBreakpoints.playerCardCornerPt;

    final isListeningRow = isPlaying && !isBuffering;
    final neutralPauseLiveDot =
        !hasRecoverableError && !(isOffline && !isBuffering) && !isListeningRow;

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: panelPaddingH,
        vertical: AppSpacing.g(isCompactHeight ? 2 : 3, scale),
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppRadii.borderRadius(cornerPt, scale),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.65 : 0.78),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(right: AppSpacing.gHalf(scale)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PlaybackStatusChip(
              isOffline: isOffline,
              hasRecoverableError: hasRecoverableError,
              isPlaying: isPlaying,
              isBuffering: isBuffering,
              isLiveMode: isLiveMode,
              scale: scale,
              narrowMobile: narrowMobile,
              labelColor: titleColor,
              isDark: isDark,
            ),
            LivePulsingIndicator(
              scale: scale,
              isEnDirect: isEnDirect,
              isPlaying: hasRecoverableError ? false : isPlaying,
              pulseEnabled: livePulseActive,
              neutralPause: neutralPauseLiveDot,
              onTap: onLiveIndicatorTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      container: true,
      label:
          'Sem ligação à Internet. Ligue os dados móveis ou o Wi‑Fi para ouvir a rádio.',
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: AppSpacing.insetSymmetric(
            layoutScale: scale,
            horizontal: 2,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.42 : 0.72,
            ),
            borderRadius: AppRadii.borderRadius(
              AppTheme.notionBlockRadius,
              scale,
            ),
            border: Border.all(
              color: scheme.outline.withValues(alpha: isDark ? 0.48 : 0.62),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: scheme.primary,
                size: AppSpacing.g(3, scale),
              ),
              SizedBox(width: AppSpacing.g(2, scale)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sem ligação à Internet',
                      style: GoogleFonts.inter(
                        fontSize: AppTypeScale.body * scale,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: AppSpacing.gHalf(scale)),
                    Text(
                      'Ligue os dados móveis ou o Wi‑Fi para ouvir a rádio.',
                      style: GoogleFonts.inter(
                        fontSize: AppTypeScale.label * scale,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const visible = kBibleFmErrorBannerHint;

    return Semantics(
      container: true,
      label: visible,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: AppSpacing.insetSymmetric(
            layoutScale: scale,
            horizontal: 2,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: (isDark ? scheme.errorContainer : scheme.error).withValues(
              alpha: isDark ? 0.28 : 0.1,
            ),
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: scheme.error.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
                size: AppSpacing.g(3, scale),
              ),
              SizedBox(width: AppSpacing.g(2, scale)),
              Expanded(
                child: Text(
                  visible,
                  style: GoogleFonts.inter(
                    fontSize: AppTypeScale.body * scale,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({
    required this.isOffline,
    required this.hasRecoverableError,
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.scale,
    required this.narrowMobile,
    required this.labelColor,
    required this.isDark,
  });

  final bool isOffline;
  final bool hasRecoverableError;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final double scale;
  final bool narrowMobile;
  final Color labelColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isListening = isPlaying && !isBuffering;
    // Com erro visível, não mostrar «écoute» só porque o player ainda reporta playing.
    final effectiveListening = isListening && !hasRecoverableError;
    final String label;
    if (isOffline && !isBuffering) {
      label = kBibleFmStatusChipOffline;
    } else if (hasRecoverableError) {
      label = kBibleFmStatusChipError;
    } else if (isListening) {
      label = isLiveMode ? kBibleFmStatusChipLive : kBibleFmStatusChipListening;
    } else {
      label = kBibleFmStatusChipPaused;
    }

    final neutralPauseChip = label == kBibleFmStatusChipPaused;

    final pillBg = AppTheme.statusPillBackground(
      scheme: scheme,
      brightness: brightness,
      isListening: effectiveListening,
      isLiveMode: isLiveMode,
      neutralPause: neutralPauseChip,
    );
    final pillBorder = AppTheme.statusPillBorder(
      scheme: scheme,
      brightness: brightness,
      isListening: effectiveListening,
      isLiveMode: isLiveMode,
      neutralPause: neutralPauseChip,
    );

    final labelPaint = effectiveListening
        ? labelColor.withValues(alpha: isDark ? 0.92 : 1)
        : neutralPauseChip
        ? scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.92 : 0.88)
        : Color.lerp(labelColor, scheme.error, isDark ? 0.42 : 0.48)!;

    final minH = math.max(AppSpacing.minTouchTarget, AppSpacing.g(6, scale));
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Container(
        alignment: Alignment.center,
        padding: AppSpacing.insetSymmetric(
          layoutScale: scale,
          horizontal: narrowMobile ? 2 : 3,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: AppRadii.borderRadius(AppRadii.pill, scale),
          border: Border.all(color: pillBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: AppTypeScale.label * scale,
                letterSpacing: 0.35,
                color: labelPaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

