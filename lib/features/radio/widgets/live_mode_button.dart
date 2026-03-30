import 'package:flutter/material.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';

/// Botão **direto / emissão** — disco circular alinhado ao [PlayButton] dentro do comprimido.
class LiveModeButton extends StatelessWidget {
  const LiveModeButton({
    super.key,
    required this.playbackLifecycle,
    required this.isLiveMode,
    required this.isPaused,
    required this.isOffline,
    required this.isLiveReloading,
    required this.onPressed,
    required this.scale,
    required this.size,
  });

  /// idle pode iniciar já em direto; em load o toque fica indisponível.
  final UiPlaybackLifecycle playbackLifecycle;
  final bool isLiveMode;
  final bool isPaused;
  final bool isOffline;
  final bool isLiveReloading;
  final VoidCallback? onPressed;
  final double scale;

  /// Diâmetro; igual ao botão play no mesmo comprimido.
  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final fillColor = AppTheme.transportPlayFill(brightness);
    final iconColor = AppTheme.transportPlayIcon(brightness);
    final broadcastIconColor =
        isDark ? Colors.black : iconColor;

    final buttonSize = size.clamp(
      AppSpacing.g(AppSpacing.playControlDiameterMinSteps, scale),
      AppSpacing.g(AppSpacing.playControlDiameterMaxSteps, scale),
    );
    final iconSize = (buttonSize * 0.38).clamp(
      AppSpacing.g(3, scale),
      AppSpacing.g(5, scale),
    );

    final canTap = onPressed != null && !isLiveReloading;
    String semanticsLabel;
    String tooltipMsg;
    if (isLiveReloading) {
      semanticsLabel = kBibleFmLiveA11yReloading;
      tooltipMsg = kBibleFmLiveTooltipReloading;
    } else if (isOffline) {
      semanticsLabel = kBibleFmLiveA11yOffline;
      tooltipMsg = kBibleFmLiveTooltipOffline;
    } else if (isTransportLoadingUiLifecycle(playbackLifecycle)) {
      semanticsLabel = kBibleFmLiveA11yWaitStabilize;
      tooltipMsg = kBibleFmLiveTooltipWaitStabilize;
    } else if (playbackLifecycle == UiPlaybackLifecycle.idle) {
      if (canTap) {
        semanticsLabel = kBibleFmLiveA11yGoLive;
        tooltipMsg = kBibleFmLiveTooltipGoLive;
      } else {
        semanticsLabel = kBibleFmLiveA11yAfterStart;
        tooltipMsg = kBibleFmLiveTooltipAfterStart;
      }
    } else if (isLiveMode && !isPaused && !canTap) {
      semanticsLabel = kBibleFmLiveA11yActive;
      tooltipMsg = kBibleFmLiveTooltipActive;
    } else if (isLiveMode && isPaused && canTap) {
      semanticsLabel = kBibleFmLiveA11yCatchUp;
      tooltipMsg = kBibleFmLiveTooltipCatchUp;
    } else if (canTap) {
      semanticsLabel = kBibleFmLiveA11yGoLive;
      tooltipMsg = kBibleFmLiveTooltipGoLive;
    } else {
      semanticsLabel = kBibleFmLiveA11yPauseToEnable;
      tooltipMsg = kBibleFmLiveTooltipPauseToEnable;
    }

    Widget circle = InkWell(
      borderRadius: BorderRadius.circular(buttonSize / 2),
      hoverColor: !canTap || isLiveReloading
          ? Colors.transparent
          : (isDark
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.12)),
      splashColor: (!canTap || isLiveReloading)
          ? Colors.transparent
          : (isDark
              ? Colors.black.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.18)),
      highlightColor:
          (!canTap || isLiveReloading) ? Colors.transparent : null,
      onTap: isLiveReloading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
        ),
        alignment: Alignment.center,
        child: isLiveReloading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                  color: iconColor,
                  backgroundColor: iconColor.withValues(alpha: 0.22),
                ),
              )
            : BroadcastSignalIcon(color: broadcastIconColor, size: iconSize),
      ),
    );
    if (isOffline) {
      circle = Opacity(opacity: 0.65, child: circle);
    } else if (isLiveReloading) {
      circle = Opacity(opacity: 1, child: circle);
    } else if (playbackLifecycle != UiPlaybackLifecycle.playing) {
      // Parado / a carregar: visual «não ao vivo» (opaco só durante reprodução).
      circle = Opacity(opacity: 0.45, child: circle);
    } else if (!canTap && !isLiveMode) {
      circle = Opacity(opacity: 0.52, child: circle);
    }

    return Semantics(
      button: true,
      selected: isLiveMode,
      enabled: canTap,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltipMsg,
        waitDuration: const Duration(milliseconds: 320),
        child: MouseRegion(
          cursor: canTap && !isLiveReloading
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: circle,
        ),
      ),
    );
  }
}
