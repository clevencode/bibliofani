import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Botão principal de reprodução (play / pausa / ligar) sem container extra.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.size = 96,
    this.enabled = true,
    this.showStoppedWhenIdle = false,
    this.layoutScale,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;
  final double size;

  /// Quando não há reprodução mas o stream está **parado por erro** (rede, servidor…),
  /// mostra o mesmo ícone **pausa** que durante a reprodução — paridade visual com o estado online.
  final bool showStoppedWhenIdle;

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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final usePauseGlyph =
        widget.isPlaying || (widget.showStoppedWhenIdle && !widget.isLoading);
    final iconData =
        usePauseGlyph ? Icons.pause_rounded : Icons.play_arrow_rounded;
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
    // Notion: disco tinta (claro) / branco (escuro), ícone inverso; bloco sólido plano.
    final fillColor = AppTheme.transportPlayFill(brightness);
    final iconColor = AppTheme.transportPlayIcon(brightness);

    final canTap = widget.enabled && widget.onTap != null;

    final String a11yLabel;
    final String tooltipMsg;
    if (widget.isLoading) {
      a11yLabel = 'A ligar ao stream';
      tooltipMsg = 'A ligar…';
    } else if (widget.isPlaying) {
      a11yLabel = 'Pausar a escuta';
      tooltipMsg = 'Pausar';
    } else if (widget.showStoppedWhenIdle) {
      a11yLabel = 'Tentar ligar de novo ao stream';
      tooltipMsg = 'Tentar de novo';
    } else {
      a11yLabel = 'Iniciar reprodução';
      tooltipMsg = 'Tocar';
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
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.12),
          splashColor: isDark
              ? Colors.black.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.18),
          // Em ligação: o toque cancela e repõe idle (equivale a parar o arranque).
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
