import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Botao principal de reproducao sem container.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.size = 96,
    this.enabled = true,
    this.layoutScale,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;
  final double size;

  /// Quando false, o toque é ignorado (ex.: operação bloqueada por outra camada).
  final bool enabled;

  /// Escala mobile-first para sombra (8pt); opcional.
  final double? layoutScale;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Trocamos entre play e pause sem animacoes de pulso.
    final iconData =
        widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final ls = widget.layoutScale ?? 1.0;
    final buttonSize = widget.size.clamp(
      AppSpacing.g(AppSpacing.playControlDiameterMinSteps, ls),
      AppSpacing.g(AppSpacing.playControlDiameterMaxSteps, ls),
    );
    final progressSize = (buttonSize * 0.33).clamp(
      AppSpacing.g(3, ls),
      AppSpacing.g(4, ls),
    );
    final iconSize = (buttonSize * 0.44).clamp(
      AppSpacing.g(4, ls),
      AppSpacing.g(6, ls),
    );
    // Preenchimento sólido: claro = disco preto + ícone branco; escuro alinhado ao [ColorScheme].
    final fillColor = isDark
        ? scheme.surfaceContainerHigh
        : const Color(0xFF0D0D0D);
    final borderColor = isDark
        ? scheme.outline.withValues(alpha: 0.42)
        : Colors.black.withValues(alpha: 0.04);
    final iconColor = isDark ? scheme.onSurface : Colors.white;

    final canTap = widget.enabled && widget.onTap != null;

    final String a11yLabel;
    final String tooltipMsg;
    if (widget.isLoading) {
      a11yLabel = 'Connexion au flux en cours';
      tooltipMsg = 'Connexion au flux…';
    } else if (widget.isPlaying) {
      a11yLabel = 'Mettre en pause la lecture';
      tooltipMsg = 'Pause';
    } else {
      a11yLabel = 'Lancer la lecture';
      tooltipMsg = 'Lecture';
    }

    return Semantics(
      button: true,
      enabled: canTap,
      label: a11yLabel,
      child: Tooltip(
        message: tooltipMsg,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(buttonSize),
          hoverColor: isDark
              ? AppTheme.darkHoverOverlay(scheme)
              : Colors.white.withValues(alpha: 0.1),
          splashColor: isDark
              ? AppTheme.darkHoverOverlay(scheme)
              : Colors.white.withValues(alpha: 0.12),
          // Mantém o toque em buffering: o loading é só visual no botão.
          onTap: canTap ? widget.onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: widget.enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? scheme.shadow : Colors.black87).withValues(
                      alpha: isDark ? 0.22 : 0.1,
                    ),
                    blurRadius: AppSpacing.g(2, ls),
                    offset: Offset(0, AppSpacing.g(1, ls)),
                  ),
                ],
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: progressSize,
                        height: progressSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: iconColor,
                        ),
                      )
                    : Icon(iconData, size: iconSize, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
