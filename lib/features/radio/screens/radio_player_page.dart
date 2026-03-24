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

/// Bible FM: layout **mobile-first** — base para telemóvel, depois tablet/paisagem.
/// Estrutura alinhada às orientações de **margens, contenção e encartes** do
/// Android ([content structure](https://developer.android.com/design/ui/mobile/guides/layout-and-content/content-structure?hl=pt-br)):
/// grelha 8 pt, ~16 dp lateral em compacto, cartão como contenção explícita,
/// área segura e corpo rolável quando o conteúdo excede a altura.
/// Estado de leitura / contador / live: [radioPlayerUiProvider].
///
/// [ConsumerStatefulWidget] para [ref] no arranque automático e no `build`.
class RadioPlayerPage extends ConsumerStatefulWidget {
  const RadioPlayerPage({super.key});

  @override
  ConsumerState<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends ConsumerState<RadioPlayerPage> {
  static const Color _chipGreyLight = Color(0xFFE8E8E8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final cardColor =
        isDark ? scheme.surfaceContainerHighest : Colors.white;
    // Pílula de estado: um degrau abaixo do cartão (hierarquia M3).
    final chipGrey = isDark ? scheme.surfaceContainerHigh : _chipGreyLight;
    // Bandeja do contador: recuada relativamente ao cartão.
    final timerTrayColor =
        isDark ? scheme.surfaceContainer : const Color(0xFFEEEEEE);
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
            _PageBackground(isDark: isDark),
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
                    AppSpacing.marginPanelInnerHorizontalSteps(narrow: isNarrow),
                    scale,
                  );
                  final panelWidth =
                      AppLayoutBreakpoints.maxPanelWidth(w, h, scale);
                  final isPhonePortrait = !AppLayoutBreakpoints.isTablet(w) &&
                      !AppLayoutBreakpoints.isLandscape(w, h);
                  final cardWidthFraction =
                      isPhonePortrait ? 0.96 : 1.0;

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
                    AppSpacing.transportStackGapSteps(
                      compactHeight: isCompact,
                    ),
                    scale,
                  );
                  final overlayContentHeight =
                      playVisualSize + postButtonGap;
                  final barReserve = overlayContentHeight +
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
                              backgroundColor:
                                  scheme.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
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
                                                _MainPlayerCard(
                                                  width: AppSpacing
                                                      .clampCardContentWidth(
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
                                                  livePulseActive: ui
                                                          .livePulseActive &&
                                                      ui.isEnDirect,
                                                  onLiveIndicatorTap: ui
                                                          .isEnDirect
                                                      ? player.toggleLivePulse
                                                      : null,
                                                  chipGrey: chipGrey,
                                                  timerTrayColor:
                                                      timerTrayColor,
                                                  titleColor: titleColor,
                                                  timerColor: timerColor,
                                                  elapsed: ui.elapsed,
                                                  onTimerTap:
                                                      player.resetElapsed,
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
                                                    message:
                                                        ui.errorMessage!,
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
                        bottom: bottomInset +
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
                            isDark: isDark,
                            narrowMobile: isNarrow,
                            isPlaying: ui.isPlaying,
                            isPaused:
                                ui.lifecycle == UiPlaybackLifecycle.paused,
                            isBuffering:
                                isBufferingUiLifecycle(ui.lifecycle),
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
  const _PageBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Claro: sólido do tema. Escuro: preto uniforme.
    if (!isDark) {
      return DecoratedBox(decoration: BoxDecoration(color: scheme.surface));
    }
    return const DecoratedBox(
      decoration: BoxDecoration(color: Colors.black),
    );
  }
}

class _BibleFmHeader extends StatelessWidget {
  const _BibleFmHeader({
    required this.scale,
    required this.titleColor,
  });

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

class _DigitalTimer extends StatelessWidget {
  const _DigitalTimer({
    required this.elapsed,
    required this.scale,
    required this.timerTrayColor,
    required this.timerColor,
    required this.onTap,
    required this.timerLayoutWidth,
    required this.narrowMobile,
  });

  final Duration elapsed;
  final double scale;
  final Color timerTrayColor;
  final Color timerColor;
  final VoidCallback onTap;

  /// Largura de referência (cartão / faixa do contador), mobile-first.
  final double timerLayoutWidth;
  final bool narrowMobile;

  @override
  Widget build(BuildContext context) {
    final mainFontSize = AppSpacing.responsiveTimerValueFontSize(
      timerLayoutWidth,
      scale,
      narrow: narrowMobile,
    );
    final d = elapsed.isNegative ? Duration.zero : elapsed;
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final a11y = _sessionDurationSemanticsFr(d);

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timerVerticalSteps = narrowMobile ? 2 : 3;
    final timerHorizontalSteps = narrowMobile ? 2 : 3;

    final digitStyle = GoogleFonts.jetBrainsMono(
      fontSize: mainFontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
      height: 1.05,
      color: timerColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final sepStyle = digitStyle.copyWith(
      fontSize: mainFontSize * 0.82,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: scheme.onSurfaceVariant,
    );

    final radius = AppRadii.borderRadius(AppRadii.sm, scale);

    return Semantics(
      button: true,
      label:
          'Temps d\'écoute, $a11y. Toucher pour remettre le compteur à zéro.',
      child: Tooltip(
        message: 'Réinitialiser le compteur',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            hoverColor: isDark
                ? AppTheme.darkHoverOverlay(scheme)
                : Colors.black.withValues(alpha: 0.06),
            splashColor: isDark
                ? AppTheme.darkHoverOverlay(scheme)
                : Colors.black.withValues(alpha: 0.08),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: timerTrayColor,
                borderRadius: radius,
                border: Border.all(
                  color: scheme.outline.withValues(alpha: isDark ? 0.16 : 0.11),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: isDark ? 0.08 : 0.06),
                    blurRadius: AppSpacing.g(2, scale),
                    offset: Offset(0, AppSpacing.gHalf(scale)),
                  ),
                ],
              ),
              child: Padding(
                padding: AppSpacing.insetSymmetric(
                  layoutScale: scale,
                  horizontal: timerHorizontalSteps,
                  vertical: timerVerticalSteps,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: digitStyle,
                        children: [
                          TextSpan(text: hh),
                          TextSpan(text: ':', style: sepStyle),
                          TextSpan(text: mm),
                          TextSpan(text: ':', style: sepStyle),
                          TextSpan(text: ss),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _sessionDurationSemanticsFr(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final parts = <String>[];
  if (h > 0) {
    parts.add(h == 1 ? '1 heure' : '$h heures');
  }
  if (m > 0) {
    parts.add(m == 1 ? '1 minute' : '$m minutes');
  }
  if (s > 0 || parts.isEmpty) {
    parts.add(s == 1 ? '1 seconde' : '$s secondes');
  }
  return parts.join(', ');
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
    required this.chipGrey,
    required this.timerTrayColor,
    required this.titleColor,
    required this.timerColor,
    required this.elapsed,
    required this.onTimerTap,
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
  final Color chipGrey;
  final Color timerTrayColor;
  final Color titleColor;
  final Color timerColor;
  final Duration elapsed;
  final VoidCallback onTimerTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusToTimerGap = AppSpacing.g(
      narrowMobile ? 2 : 3,
      scale,
    );
    final timerBodyWidth =
        math.max(0.0, width - 2 * panelPaddingH);
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
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(
              alpha: isDark ? 0.32 : 0.07,
            ),
            blurRadius: AppSpacing.g(3, scale),
            offset: Offset(0, AppSpacing.g(1, scale)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(
              right: AppSpacing.gHalf(scale),
            ),
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
                  chipGrey: chipGrey,
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
          _DigitalTimer(
            elapsed: elapsed,
            scale: scale,
            timerTrayColor: timerTrayColor,
            timerColor: timerColor,
            onTap: onTimerTap,
            timerLayoutWidth: timerBodyWidth,
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
          color: (isDark ? scheme.errorContainer : scheme.error)
              .withValues(alpha: isDark ? 0.28 : 0.1),
          borderRadius: AppRadii.borderRadius(AppRadii.sm, scale),
          border: Border.all(
            color: scheme.error.withValues(alpha: 0.65),
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
                    style: GoogleFonts.dmSans(
                      fontSize: AppTypeScale.body * scale,
                      fontWeight: FontWeight.w700,
                      color: scheme.error,
                    ),
                  ),
                  SizedBox(height: AppSpacing.gHalf(scale)),
                  Text(
                    'Vérifiez votre connexion ou réessayez.',
                    style: GoogleFonts.dmSans(
                      fontSize: AppTypeScale.label * scale,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.7),
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
                textStyle: GoogleFonts.dmSans(
                  fontSize: AppTypeScale.label * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppSpacing.halfGrid * 0.1 * scale,
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
    required this.chipGrey,
    required this.labelColor,
    required this.isDark,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final double scale;
  final bool narrowMobile;
  final Color chipGrey;
  final Color labelColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isListening = isPlaying && !isBuffering;
    final label = isListening
        ? (isLiveMode ? 'En direct' : 'Différé')
        : 'En pause';

    final minH = math.max(
      AppSpacing.minTouchTarget,
      AppSpacing.g(6, scale),
    );
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
          color: chipGrey,
          borderRadius: AppRadii.borderRadius(AppRadii.pill, scale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                fontSize: AppTypeScale.label * scale,
                letterSpacing: AppSpacing.gHalf(scale) * 0.22,
                color: isDark
                    ? labelColor.withValues(alpha: 0.92)
                    : labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
