import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';

/// Botão de modo direto em formato **pílula** (barra de transporte).
class LiveModeButton extends StatelessWidget {
  const LiveModeButton({
    super.key,
    required this.isLiveMode,
    required this.isPaused,
    required this.onPressed,
    required this.scale,
    required this.size,
    required this.isDark,
    this.narrowMobile = false,
  });

  final bool isLiveMode;
  final bool isPaused;
  final VoidCallback? onPressed;
  final double scale;

  /// Diâmetro do play à direita; na pílula é a **altura** do comprimido.
  final double size;
  final bool isDark;

  /// Mobile-first: pílula mais longa em ecrãs estreitos (referência visual).
  final bool narrowMobile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = isDark ? scheme.onSurface : const Color(0xFF141414);
    final baseFillColor =
        isDark ? scheme.surfaceContainerHighest : Colors.white;
    final differFillColor = Colors.white.withValues(alpha: 0.7);
    // Estados visuais:
    // - live: preenchimento total
    // - differe (tocando fora do live): 50% opaco
    // - pausa fora do live: sem preenchimento
    final fillColor = isLiveMode
        ? baseFillColor
        : (isPaused
            ? Colors.transparent
            : differFillColor);
    final borderColor = isDark
        ? scheme.outline.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.18);

    final iconSize = (size * 0.38).clamp(
      AppSpacing.g(3, scale),
      AppSpacing.g(5, scale),
    );

    final canTap = onPressed != null;
    String semanticsLabel;
    String tooltipMsg;
    if (isLiveMode && isPaused && canTap) {
      semanticsLabel = 'Rattraper le direct par paliers';
      tooltipMsg =
          'Rapprocher le compteur du direct sans remettre à zéro (répéter après pause)';
    } else if (isLiveMode && !isPaused) {
      semanticsLabel = 'Direct actif';
      tooltipMsg = 'Direct actif';
    } else if (!canTap) {
      semanticsLabel = 'Direct : mettre la lecture en pause pour activer';
      tooltipMsg = 'Mettre la lecture en pause pour activer l’écoute du direct';
    } else {
      semanticsLabel = 'Passer en écoute du direct';
      tooltipMsg = 'Écouter le direct';
    }

    final radius = size / 2;
    final pillWFactor = narrowMobile ? 2.28 : 2.05;
    final pillWidth = math.max(
      size * pillWFactor,
      AppSpacing.g(
        AppSpacing.livePillMinWidthSteps(narrow: narrowMobile),
        scale,
      ),
    );
    final pillHeight = size;

    final liveShadow = BoxShadow(
      color: scheme.shadow.withValues(alpha: isDark ? 0.38 : 0.1),
      blurRadius: AppSpacing.g(2, scale),
      offset: Offset(0, AppSpacing.g(1, scale)),
    );
    final differShadow = BoxShadow(
      color: scheme.shadow.withValues(alpha: isDark ? 0.24 : 0.07),
      blurRadius: AppSpacing.g(2, scale) * 0.75,
      offset: Offset(0, AppSpacing.gHalf(scale)),
    );

    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: isLiveMode
          ? [liveShadow]
          : (isPaused ? const [] : [differShadow]),
    );

    final child = BroadcastSignalIcon(color: iconColor, size: iconSize);

    Widget pill = InkWell(
      borderRadius: BorderRadius.circular(radius),
      hoverColor: !canTap
          ? Colors.transparent
          : (isDark
                ? AppTheme.darkHoverOverlay(scheme)
                : Colors.black.withValues(alpha: 0.06)),
      splashColor: !canTap
          ? Colors.transparent
          : (isDark
                ? AppTheme.darkHoverOverlay(scheme)
                : Colors.black.withValues(alpha: 0.08)),
      highlightColor: !canTap ? Colors.transparent : null,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: pillWidth,
        height: pillHeight,
        alignment: Alignment.center,
        decoration: decoration,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.g(1, scale)),
        child: child,
      ),
    );
    if (!canTap && !isLiveMode) {
      pill = Opacity(opacity: 0.5, child: pill);
    }

    return Semantics(
      button: true,
      selected: isLiveMode,
      enabled: canTap,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltipMsg,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: pill,
        ),
      ),
    );
  }
}
