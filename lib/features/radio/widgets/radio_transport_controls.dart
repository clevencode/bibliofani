import 'package:flutter/material.dart';
import 'package:meu_app/features/radio/widgets/live_mode_button.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

/// Barra inferior: **play** circular à esquerda, **live** em pílula à direita.
class RadioTransportControls extends StatelessWidget {
  const RadioTransportControls({
    super.key,
    required this.scale,
    required this.playVisualSize,
    required this.isDark,
    required this.narrowMobile,
    required this.isPlaying,
    required this.isPaused,
    required this.isBuffering,
    required this.isLiveMode,
    required this.onCentralTap,
    required this.onLiveTap,
  });

  final double scale;
  final double playVisualSize;
  final bool isDark;
  final bool narrowMobile;
  final bool isPlaying;
  final bool isPaused;
  final bool isBuffering;
  final bool isLiveMode;
  final VoidCallback onCentralTap;
  /// Null quando o direct não pode ser activado (ex.: déjà en direct, ou pas en pause).
  final VoidCallback? onLiveTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Contrôles de lecture : lecture ou pause à gauche, direct à droite',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayButton(
            isPlaying: isPlaying,
            isLoading: isBuffering,
            onTap: onCentralTap,
            size: playVisualSize,
            layoutScale: scale,
          ),
          LiveModeButton(
            isLiveMode: isLiveMode,
            isPaused: isPaused,
            onPressed: onLiveTap,
            scale: scale,
            size: playVisualSize,
            isDark: isDark,
            narrowMobile: narrowMobile,
          ),
        ],
      ),
    );
  }
}
