import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Indicador «ao vivo»: vermelho em direct; cinza quando não está em [isLiveMode].
/// [pulseEnabled] controla o pulso (só relevante em direct).
/// [onTap] — ex.: só em «en direct» o pai ativa a animação.
class LivePulsingIndicator extends StatefulWidget {
  const LivePulsingIndicator({
    super.key,
    required this.scale,
    required this.isLiveMode,
    required this.pulseEnabled,
    this.onTap,
    this.tooltip,
  });

  final double scale;
  final bool isLiveMode;
  final bool pulseEnabled;
  final VoidCallback? onTap;

  /// Si non null, remplace le texte d'aide au survol / long appui.
  final String? tooltip;

  @override
  State<LivePulsingIndicator> createState() => _LivePulsingIndicatorState();
}

class _LivePulsingIndicatorState extends State<LivePulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(LivePulsingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulseEnabled != widget.pulseEnabled ||
        oldWidget.isLiveMode != widget.isLiveMode) {
      _syncPulseAnimation();
    }
  }

  void _syncPulseAnimation() {
    if (widget.isLiveMode && widget.pulseEnabled) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _haloRing({
    required double t,
    required double phase,
    required double coreD,
    required Color accent,
  }) {
    final u = ((t + phase) % 1.0);
    final eased = Curves.easeOutCubic.transform(u);
    final haloScale = 0.78 + 0.42 * eased;
    final haloOpacity = 0.42 * (1 - eased).clamp(0.0, 1.0);
    return Transform.scale(
      scale: haloScale,
      child: Container(
        width: coreD * 2.35,
        height: coreD * 2.35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: haloOpacity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.scale;
    final coreD = AppSpacing.g(2, s) - AppSpacing.gHalf(s) * 0.5;
    final outerSize = AppSpacing.g(4, s);
    const liveRed = Color(0xFFE53935);
    final idleGray = scheme.outline;
    final accent = widget.isLiveMode ? liveRed : idleGray;

    final defaultTooltip = !widget.isLiveMode
        ? 'Lecture différée (pas en direct)'
        : widget.onTap == null
            ? 'Signal du direct (fixe). Passez en direct pour l’animer.'
            : widget.pulseEnabled
                ? 'Appuyez pour arrêter l’animation du signal'
                : 'Appuyez pour animer le signal du direct';

    final tooltipText = widget.tooltip ?? defaultTooltip;

    final String a11yLabel;
    final String? a11yHint;
    if (!widget.isLiveMode) {
      a11yLabel = 'Indicateur différé, pas en direct';
      a11yHint = null;
    } else if (widget.onTap == null) {
      a11yLabel = 'Indicateur du direct, signal fixe';
      a11yHint = null;
    } else if (widget.pulseEnabled) {
      a11yLabel = 'Signal du direct animé';
      a11yHint = 'Appuyez pour arrêter l’animation';
    } else {
      a11yLabel = 'Signal du direct';
      a11yHint = 'Appuyez pour activer l’animation';
    }

    Widget indicator = Semantics(
      label: a11yLabel,
      hint: a11yHint,
      button: widget.onTap != null,
      child: RepaintBoundary(
        child: SizedBox(
          width: outerSize,
          height: outerSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = widget.isLiveMode && widget.pulseEnabled
                  ? _controller.value
                  : 0.0;
              final shadowColor = widget.isLiveMode
                  ? const Color(0x33E53935)
                  : scheme.shadow.withValues(alpha: isDark ? 0.35 : 0.12);
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _haloRing(t: t, phase: 0, coreD: coreD, accent: accent),
                  _haloRing(t: t, phase: 0.5, coreD: coreD, accent: accent),
                  Container(
                    width: coreD,
                    height: coreD,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: AppSpacing.gHalf(s),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      indicator = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          hoverColor: isDark
              ? AppTheme.darkHoverOverlay(scheme)
              : Colors.black.withValues(alpha: 0.06),
          splashColor: isDark
              ? AppTheme.darkHoverOverlay(scheme)
              : Colors.black.withValues(alpha: 0.08),
          child: indicator,
        ),
      );
    }

    // Cible tactile ~48 pt (Material) autour du pictogramme.
    final minSide = AppSpacing.g(6, s);
    indicator = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSide,
        minHeight: minSide,
      ),
      child: Center(child: indicator),
    );

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 450),
      child: indicator,
    );
  }
}
