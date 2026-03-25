import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Botao principal de reproducao sem container.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    this.isPreparing = false,
    required this.onTap,
    this.size = 96,
    this.enabled = true,
    this.isOffline = false,
    this.onOfflineRestartApp,
    this.recoveryUiActive = false,
    this.refreshRestartsEntireApp = true,
    this.layoutScale,
  });

  final bool isPlaying;
  final bool isLoading;

  /// Quando [isLoading] é verdadeiro: fase [preparing] vs [buffering] (textos distintos).
  final bool isPreparing;
  final VoidCallback? onTap;
  final double size;

  /// Quando false, o toque é ignorado (ex.: operação bloqueada por outra camada).
  final bool enabled;

  /// Sem rede e sem leitura activa: explica tooltip / acessibilidade.
  final bool isOffline;

  /// Quando não-null: ícone [Icons.refresh_rounded] (também durante load se [recoveryUiActive]).
  final VoidCallback? onOfflineRestartApp;

  /// Offline ou erro: refresh prevalece sobre o spinner de load.
  final bool recoveryUiActive;

  /// Quando false (ex.: online com erro), o refresh só tenta religar o fluxo, não reinicia o processo.
  final bool refreshRestartsEntireApp;

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
    final ls = widget.layoutScale ?? 1.0;
    // Offline/erro: refresh em vez de play ou spinner, em qualquer fase do transporte.
    final restartMode = widget.onOfflineRestartApp != null &&
        (!widget.isLoading || widget.recoveryUiActive);
    final IconData iconData = restartMode
        ? Icons.refresh_rounded
        : (widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded);
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

    final canTap = restartMode ||
        (widget.enabled && widget.onTap != null);
    final effectiveOpacity = restartMode || widget.enabled ? 1.0 : 0.45;

    final String a11yLabel;
    final String tooltipMsg;
    if (restartMode) {
      if (widget.refreshRestartsEntireApp) {
        a11yLabel = 'Reiniciar a aplicação';
        tooltipMsg = widget.isOffline
            ? 'Sem ligação — reiniciar a app ou restabeleça a rede'
            : 'Erro no fluxo — reiniciar a app ou tente novamente';
      } else {
        a11yLabel = 'Tentar religar o fluxo';
        tooltipMsg =
            'Erro ou interrupção — toque para voltar a ligar à rádio';
      }
    } else if (widget.isOffline && !widget.isPlaying && !widget.isLoading) {
      a11yLabel = 'Lecture indisponible sans connexion réseau';
      tooltipMsg = 'Sem ligação à Internet';
    } else if (widget.isLoading) {
      if (widget.isPreparing) {
        a11yLabel = 'A preparar o fluxo de áudio';
        tooltipMsg = 'A preparar o fluxo…';
      } else {
        a11yLabel = 'A ligar ao fluxo';
        tooltipMsg = 'A ligar ao fluxo…';
      }
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
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.12),
          splashColor: isDark
              ? Colors.black.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.18),
          onTap: canTap
              ? () {
                  if (restartMode) {
                    widget.onOfflineRestartApp?.call();
                  } else {
                    widget.onTap?.call();
                  }
                }
              : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: effectiveOpacity,
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
                child: widget.isLoading && !restartMode
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
