import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';

/// Botão de modo direto em formato **pílula** (barra de transporte).
class LiveModeButton extends StatelessWidget {
  const LiveModeButton({
    super.key,
    required this.playbackLifecycle,
    required this.isLiveMode,
    required this.isPaused,
    required this.isOffline,
    required this.onPressed,
    required this.scale,
    required this.size,
    this.narrowMobile = false,
  });

  /// Ordem: idle → carregar → play/pause; direct só após haver sessão de leitura.
  final UiPlaybackLifecycle playbackLifecycle;
  final bool isLiveMode;
  final bool isPaused;
  final bool isOffline;
  final VoidCallback? onPressed;
  final double scale;

  /// Diâmetro do play à direita; na pílula é a **altura** do comprimido.
  final double size;

  /// Mobile-first: pílula mais longa em ecrãs estreitos (referência visual).
  final bool narrowMobile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final iconColor = AppTheme.transportLiveIcon(brightness);
    // Escuro: painel elevado. Claro: papel (#F3F2EF) — branco puro sumia no gradiente.
    final baseFillColor = brightness == Brightness.light
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHighest;
    final liveBorderColor = brightness == Brightness.light
        ? AppTheme.transportLiveBorder(brightness)
        : scheme.outline.withValues(alpha: 0.85);
    // Preenchimento sólido só com directo **ativo** (a ouvir em live, sem pausa).
    // Em pause ou em différé: só traço (sem preenchimento).
    final liveSurfaceActive = isLiveMode && !isPaused;
    final fillColor = liveSurfaceActive ? baseFillColor : Colors.transparent;
    final borderColor = liveBorderColor;

    final iconSize = (size * 0.38).clamp(
      AppSpacing.g(3, scale),
      AppSpacing.g(5, scale),
    );

    final canTap = onPressed != null;
    String semanticsLabel;
    String tooltipMsg;
    if (isOffline) {
      semanticsLabel = 'Direct indisponível sem rede';
      tooltipMsg = 'Sem ligação à Internet';
    } else if (isTransportLoadingUiLifecycle(playbackLifecycle)) {
      semanticsLabel = 'Directo após o fluxo estabilizar';
      tooltipMsg = 'Aguarde o fluxo estabilizar antes do directo';
    } else if (playbackLifecycle == UiPlaybackLifecycle.idle) {
      semanticsLabel = 'Directo após iniciar a leitura';
      tooltipMsg = 'Inicie a leitura antes de activar o directo';
    } else if (isLiveMode && !isPaused && !canTap) {
      semanticsLabel = 'Direct actif';
      tooltipMsg = 'Direct actif';
    } else if (isLiveMode && isPaused && canTap) {
      semanticsLabel = 'Rattraper le direct par paliers';
      tooltipMsg =
          'Rapprocher le compteur du direct sans remettre à zéro (répéter après pause)';
    } else if (canTap) {
      semanticsLabel = 'Passer en écoute du direct';
      tooltipMsg = 'Écouter le direct';
    } else {
      semanticsLabel = 'Direct : mettre la lecture en pause pour activer';
      tooltipMsg = 'Mettre la lecture en pause pour activer l’écoute du direct';
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

    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
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
    if (isOffline) {
      pill = Opacity(opacity: 0.65, child: pill);
    } else if (!canTap && !isLiveMode) {
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
