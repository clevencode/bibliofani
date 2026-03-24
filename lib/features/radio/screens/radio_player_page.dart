import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meu_app/core/app/app_restart.dart';
import 'package:meu_app/core/network/network_connectivity_provider.dart';
import 'package:meu_app/core/platform/android_post_notifications.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/core/theme/app_theme_mode_toggle.dart';
import 'package:meu_app/features/radio/providers/radio_player_ui_provider.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/live_pulsing_indicator.dart';
import 'package:meu_app/features/radio/widgets/radio_transport_controls.dart';
import 'package:meu_app/features/radio/widgets/voice_bars_visualizer.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ensureAndroidPostNotificationsPermission());
      unawaited(_maybeAutoStartAfterConnectivity());
    });
  }

  /// Primeira leitura de rede; se estiver offline, marca arranque quando voltar a haver rede.
  Future<void> _maybeAutoStartAfterConnectivity() async {
    if (!mounted) return;
    await ref.read(networkLinkProvider.notifier).initialConnectivityFuture;
    if (!mounted) return;
    if (ref.read(networkOfflineProvider)) {
      _deferAutostartUntilOnline = true;
      return;
    }
    _deferAutostartUntilOnline = false;
    await ref.read(radioPlayerUiProvider.notifier).autoStartLivePlayback();
  }

  /// Refresh: offline reinicia o processo; online só repõe o leitor e religa o fluxo.
  Future<void> _onRefreshPressed() async {
    if (!mounted) return;
    if (ref.read(networkOfflineProvider)) {
      await restartApplication();
      return;
    }
    await ref.read(radioPlayerUiProvider.notifier).recoverPlaybackSoft();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RadioNetworkLink>(networkLinkProvider, (previous, next) {
      final wasOffline = previous == RadioNetworkLink.offline;
      final onlineNow = next != RadioNetworkLink.offline;
      if (wasOffline && onlineNow) {
        final radio = ref.read(radioPlayerUiProvider.notifier);
        radio.onConnectivityRestored();
        if (_deferAutostartUntilOnline) {
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
    });

    final ui = ref.watch(radioPlayerUiProvider);
    final player = ref.read(radioPlayerUiProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = scheme.surfaceContainerHighest;
    final timerTrayColor = scheme.surfaceContainerLow;
    final titleColor = scheme.onSurface;
    final timerColor = scheme.onSurface;

    final showStreamLoading = isTransportLoadingUiLifecycle(ui.lifecycle);
    final networkLink = ref.watch(networkLinkProvider);
    final isOffline = networkLink.isOffline;

    return Semantics(
      container: true,
      label: 'Bible FM, lecteur radio',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _PageBackground(),
            SafeArea(
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
                    AppSpacing.marginTransportHorizontalSteps(narrow: isNarrow),
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
                    AppSpacing.g(AppSpacing.playControlDiameterMinSteps, scale),
                    AppSpacing.g(AppSpacing.playControlDiameterMaxSteps, scale),
                  );
                  final postButtonGap = AppSpacing.g(
                    AppSpacing.transportStackGapSteps(compactHeight: isCompact),
                    scale,
                  );
                  final overlayContentHeight = playVisualSize + postButtonGap;
                  final barReserve =
                      overlayContentHeight +
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
                          child: IgnorePointer(
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: scheme.primary,
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                sidePadding,
                                AppSpacing.g(
                                  AppSpacing.sectionVerticalPaddingSteps,
                                  scale,
                                ),
                                sidePadding,
                                AppSpacing.g(
                                  AppSpacing.sectionVerticalPaddingSteps,
                                  scale,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _BibleFmHeader(
                                    scale: scale,
                                    titleColor: titleColor,
                                  ),
                                  if (networkLink.showsTransportHint) ...[
                                    SizedBox(height: AppSpacing.gHalf(scale)),
                                    _NetworkTransportHint(
                                      link: networkLink,
                                      scale: scale,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Erro da fonte fixo acima da área rolável em offline
                            // (evita que desapareça ao deslocar o cartão / conteúdo).
                            if (isOffline && ui.errorMessage != null)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  sidePadding,
                                  0,
                                  sidePadding,
                                  AppSpacing.g(2, scale),
                                ),
                                child: _ErrorBanner(
                                  message: ui.errorMessage!,
                                  scale: scale,
                                  onRetry: () =>
                                      unawaited(player.retryErrorBanner()),
                                ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: barReserve),
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
                                      return SingleChildScrollView(
                                        clipBehavior: Clip.none,
                                        physics: const ClampingScrollPhysics(),
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
                                                if (isOffline) ...[
                                                  _OfflineBanner(scale: scale),
                                                  SizedBox(
                                                    height: AppSpacing.g(
                                                      3,
                                                      scale,
                                                    ),
                                                  ),
                                                ],
                                                _MainPlayerCard(
                                                  width:
                                                      AppSpacing.clampCardContentWidth(
                                                        contentWidth:
                                                            innerConstraints
                                                                .maxWidth,
                                                        panelCap: panelWidth,
                                                        contentWidthFraction:
                                                            cardWidthFraction,
                                                      ),
                                                  panelPaddingH: panelPaddingH,
                                                  cardColor: cardColor,
                                                  isDark: isDark,
                                                  scale: scale,
                                                  isCompactHeight: isCompact,
                                                  narrowMobile: isNarrow,
                                                  isOffline: isOffline,
                                                  isPlaying: ui.isPlaying,
                                                  isBuffering:
                                                      isTransportLoadingUiLifecycle(
                                                        ui.lifecycle,
                                                      ),
                                                  isLiveMode: ui.isLiveMode,
                                                  isEnDirect: ui.isEnDirect,
                                                  livePulseActive:
                                                      ui.livePulseActive &&
                                                      ui.isEnDirect,
                                                  onLiveIndicatorTap:
                                                      ui.isEnDirect
                                                      ? player.toggleLivePulse
                                                      : null,
                                                  timerTrayColor:
                                                      timerTrayColor,
                                                  titleColor: titleColor,
                                                  timerColor: timerColor,
                                                ),
                                                if (ui.errorMessage != null &&
                                                    !isOffline) ...[
                                                  SizedBox(
                                                    height: AppSpacing.g(
                                                      3,
                                                      scale,
                                                    ),
                                                  ),
                                                  _ErrorBanner(
                                                    message: ui.errorMessage!,
                                                    scale: scale,
                                                    onRetry: () => unawaited(
                                                      player.retryErrorBanner(),
                                                    ),
                                                  ),
                                                ],
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
                      Positioned(
                        left: transportSidePadding,
                        right: transportSidePadding,
                        bottom:
                            bottomInset +
                            AppSpacing.g(
                              AppSpacing.transportBottomMarginSteps,
                              scale,
                            ),
                        child: Material(
                          color: Colors.transparent,
                          // Por último no Stack: toques na barra têm prioridade.
                          child: RadioTransportControls(
                            scale: scale,
                            playVisualSize: playVisualSize,
                            narrowMobile: isNarrow,
                            isOffline: isOffline,
                            playbackLifecycle: ui.lifecycle,
                            isPlaying: ui.isPlaying,
                            isPaused:
                                ui.lifecycle == UiPlaybackLifecycle.paused,
                            isBuffering: isTransportLoadingUiLifecycle(ui.lifecycle),
                            isPreparing:
                                ui.lifecycle == UiPlaybackLifecycle.preparing,
                            isLiveMode: ui.isLiveMode,
                            onTransportTap: () => unawaited(player.transportTap()),
                            onLiveTap: isOffline
                                ? null
                                : (ui.canTapLive ? player.liveTap : null),
                            onOfflineRestartApp:
                                !isTransportLoadingUiLifecycle(ui.lifecycle) &&
                                        (isOffline || ui.errorMessage != null)
                                    ? () => unawaited(_onRefreshPressed())
                                    : null,
                            refreshRestartsEntireApp: isOffline,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

class _BibleFmHeader extends StatelessWidget {
  const _BibleFmHeader({required this.scale, required this.titleColor});

  final double scale;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final titleFont = AppSpacing.responsiveBrandTitleFontSize(w, scale);
    // Sem padding horizontal extra: alinha com as margens do cartão ([sidePadding]).
    return Row(
      children: [
        Text(
          'BIBLE FM',
          style: GoogleFonts.russoOne(
            color: titleColor,
            fontSize: titleFont,
            letterSpacing: AppSpacing.gHalf(scale) * 0.3,
          ),
        ),
        const Spacer(),
        AppThemeModeToggle(layoutScale: scale),
      ],
    );
  }
}

/// Indicação discreta do tipo de ligação (destaque ao Wi‑Fi e aviso em dados móveis).
class _NetworkTransportHint extends StatelessWidget {
  const _NetworkTransportHint({
    required this.link,
    required this.scale,
  });

  final RadioNetworkLink link;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final IconData icon;
    late final String label;
    late final Color tint;
    switch (link) {
      case RadioNetworkLink.wifi:
        icon = Icons.wifi_rounded;
        label = 'Wi‑Fi ligado';
        tint = scheme.primary;
        break;
      case RadioNetworkLink.cellular:
        icon = Icons.signal_cellular_alt_rounded;
        label = 'Dados móveis — pode consumir tráfego';
        tint = scheme.tertiary;
        break;
      case RadioNetworkLink.ethernet:
        icon = Icons.settings_ethernet_rounded;
        label = 'Ethernet';
        tint = scheme.primary;
        break;
      case RadioNetworkLink.vpn:
        icon = Icons.vpn_key_rounded;
        label = 'VPN activa';
        tint = scheme.onSurfaceVariant;
        break;
      case RadioNetworkLink.other:
        icon = Icons.podcasts_rounded;
        label = 'Rede ligada';
        tint = scheme.onSurfaceVariant;
        break;
      case RadioNetworkLink.unknown:
      case RadioNetworkLink.offline:
        return const SizedBox.shrink();
    }

    return Semantics(
      label: label,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSpacing.g(2, scale) * 1.1,
            color: tint.withValues(alpha: 0.92),
          ),
          SizedBox(width: AppSpacing.gHalf(scale)),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: AppTypeScale.label * scale * 0.95,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                height: 1.25,
              ),
            ),
          ),
        ],
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
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.isEnDirect,
    required this.livePulseActive,
    required this.onLiveIndicatorTap,
    required this.timerTrayColor,
    required this.titleColor,
    required this.timerColor,
  });

  final double width;
  final double panelPaddingH;
  final Color cardColor;
  final bool isDark;
  final double scale;
  final bool isCompactHeight;
  final bool narrowMobile;
  final bool isOffline;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final bool isEnDirect;
  final bool livePulseActive;
  final VoidCallback? onLiveIndicatorTap;
  final Color timerTrayColor;
  final Color titleColor;
  final Color timerColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusToTimerGap = AppSpacing.g(narrowMobile ? 2 : 3, scale);
    final timerBodyWidth = math.max(0.0, width - 2 * panelPaddingH);
    const cornerPt = AppLayoutBreakpoints.playerCardCornerPt;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.gHalf(scale)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PlaybackStatusChip(
                  isOffline: isOffline,
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
                  isPlaying: isPlaying,
                  pulseEnabled: livePulseActive,
                  onTap: onLiveIndicatorTap,
                ),
              ],
            ),
          ),
          SizedBox(height: statusToTimerGap),
          VoiceBarsVisualizer(
            isActive: isPlaying && !isBuffering,
            scale: scale,
            barColor: timerColor,
            trayColor: timerTrayColor,
            layoutWidth: timerBodyWidth,
            narrowMobile: narrowMobile,
          ),
        ],
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
            borderRadius:
                AppRadii.borderRadius(AppTheme.notionBlockRadius, scale),
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
  const _ErrorBanner({
    required this.message,
    required this.scale,
    required this.onRetry,
  });

  final String message;
  final double scale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
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
          borderRadius: AppRadii.borderRadius(AppTheme.notionBlockRadius, scale),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: AppTypeScale.body * scale,
                      fontWeight: FontWeight.w600,
                      color: scheme.error,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: AppSpacing.gHalf(scale)),
                  Text(
                    'Vérifiez votre connexion ou réessayez.',
                    style: GoogleFonts.inter(
                      fontSize: AppTypeScale.label * scale,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.g(2, scale)),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                textStyle: GoogleFonts.inter(
                  fontSize: AppTypeScale.label * scale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              child: const Text('RÉESSAYER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({
    required this.isOffline,
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.scale,
    required this.narrowMobile,
    required this.labelColor,
    required this.isDark,
  });

  final bool isOffline;
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
    final String label;
    if (isOffline && !isBuffering) {
      label = 'Hors ligne';
    } else if (isListening) {
      label = isLiveMode ? 'En direct' : 'En écoute';
    } else {
      label = 'En pause';
    }

    final pillBg = AppTheme.statusPillBackground(
      scheme: scheme,
      brightness: brightness,
      isListening: isListening,
      isLiveMode: isLiveMode,
    );
    final pillBorder = AppTheme.statusPillBorder(
      scheme: scheme,
      brightness: brightness,
      isListening: isListening,
      isLiveMode: isLiveMode,
    );

    final labelPaint = isListening
        ? labelColor.withValues(alpha: isDark ? 0.92 : 1)
        : Color.lerp(
            labelColor,
            scheme.error,
            isDark ? 0.42 : 0.48,
          )!;

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
          border: Border.all(
            color: pillBorder,
            width: 1,
          ),
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
