import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  @override
  void initState() {
    super.initState();
    _schedulePlaybackAfterFirstFrame();
  }

  /// Espera um frame renderizado para não competir com o layout/tema no arranque.
  void _schedulePlaybackAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(radioPlayerUiProvider.notifier).autoStartLivePlayback(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(radioPlayerUiProvider);
    final player = ref.read(radioPlayerUiProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = scheme.surfaceContainerHighest;
    final timerTrayColor = scheme.surfaceContainerLow;
    final titleColor = scheme.onSurface;
    final timerColor = scheme.onSurface;

    final showStreamLoading = isBufferingUiLifecycle(ui.lifecycle);

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
                              child: _BibleFmHeader(
                                scale: scale,
                                titleColor: titleColor,
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
                                                  isPlaying: ui.isPlaying,
                                                  isBuffering:
                                                      isBufferingUiLifecycle(
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
                                                if (ui.errorMessage !=
                                                    null) ...[
                                                  SizedBox(
                                                    height: AppSpacing.g(
                                                      3,
                                                      scale,
                                                    ),
                                                  ),
                                                  _ErrorBanner(
                                                    message: ui.errorMessage!,
                                                    scale: scale,
                                                    onRetry:
                                                        player.retryAfterError,
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
                            isPlaying: ui.isPlaying,
                            isPaused:
                                ui.lifecycle == UiPlaybackLifecycle.paused,
                            isBuffering: isBufferingUiLifecycle(ui.lifecycle),
                            isLiveMode: ui.isLiveMode,
                            onCentralTap: () => unawaited(player.centralTap()),
                            onLiveTap: ui.canTapLive ? player.liveTap : null,
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

class _MainPlayerCard extends StatelessWidget {
  const _MainPlayerCard({
    required this.width,
    required this.panelPaddingH,
    required this.cardColor,
    required this.isDark,
    required this.scale,
    required this.isCompactHeight,
    required this.narrowMobile,
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
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.scale,
    required this.narrowMobile,
    required this.labelColor,
    required this.isDark,
  });

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
    final label = isListening
        ? (isLiveMode ? 'En direct' : 'En écoute')
        : 'En pause';

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
