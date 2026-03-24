import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Cinco barras verticais em cápsula (equalizador), alinhadas ao eixo central.
/// Anima quando [isActive] (reprodução efectiva, sem buffering).
class VoiceBarsVisualizer extends StatefulWidget {
  const VoiceBarsVisualizer({
    super.key,
    required this.isActive,
    required this.scale,
    required this.barColor,
    required this.trayColor,
    required this.layoutWidth,
    required this.narrowMobile,
  });

  final bool isActive;
  final double scale;
  final Color barColor;
  final Color trayColor;
  final double layoutWidth;
  final bool narrowMobile;

  @override
  State<VoiceBarsVisualizer> createState() => _VoiceBarsVisualizerState();
}

class _VoiceBarsVisualizerState extends State<VoiceBarsVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// Repouso: centro alto, interiores médios, exteriores curtos (referência visual).
  static const List<double> _restRatio = [0.26, 0.64, 1.0, 0.64, 0.26];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(VoiceBarsVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller
          ..stop()
          ..reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _maxCenterHeight {
    final fs = AppSpacing.responsiveTimerValueFontSize(
      widget.layoutWidth,
      widget.scale,
      narrow: widget.narrowMobile,
    );
    return fs * 1.28;
  }

  double _barHeight(int index, double t) {
    final base = _restRatio[index];
    final maxH = _maxCenterHeight;
    if (!widget.isActive) {
      final h = base * 0.22 * maxH;
      return h;
    }
    final a = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 1.35 + index * 0.19));
    final b = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 2.05 + index * 0.37));
    final mix = 0.44 * a + 0.56 * b;
    return base * (0.36 + 0.64 * mix) * maxH;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = AppRadii.borderRadius(AppTheme.notionBlockRadius, widget.scale);
    final vSteps = widget.narrowMobile ? 2 : 3;
    final hSteps = widget.narrowMobile ? 2 : 3;
    final barW = math.max(AppSpacing.gHalf(widget.scale) * 1.12, 3.0);
    final gap = barW * 0.4;

    return Semantics(
      label: widget.isActive
          ? 'Indicateur audio, lecture en cours'
          : 'Indicateur audio, lecture en pause ou mise en mémoire',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.trayColor,
          borderRadius: radius,
          border: Border.all(
            color: scheme.outline.withValues(alpha: isDark ? 0.38 : 0.52),
            width: 1,
          ),
        ),
        child: Padding(
          padding: AppSpacing.insetSymmetric(
            layoutScale: widget.scale,
            horizontal: hSteps,
            vertical: vSteps,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return RepaintBoundary(
                child: SizedBox(
                  height: _maxCenterHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++) ...[
                        if (i > 0) SizedBox(width: gap),
                        _CapsuleBar(
                          width: barW,
                          height: _barHeight(i, t),
                          minHeight: barW * 0.48,
                          color: widget.barColor,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CapsuleBar extends StatelessWidget {
  const _CapsuleBar({
    required this.width,
    required this.height,
    required this.minHeight,
    required this.color,
  });

  final double width;
  final double height;
  final double minHeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final h = math.max(minHeight, height);
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.5),
        color: color,
      ),
    );
  }
}
