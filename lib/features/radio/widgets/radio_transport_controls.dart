import 'package:flutter/material.dart';
import 'package:meu_app/features/radio/widgets/live_mode_button.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

/// Barra inferior: **play** circular à esquerda, **live** em pílula à direita.
class RadioTransportControls extends StatelessWidget {
  const RadioTransportControls({
    super.key,
    required this.scale,
    required this.playVisualSize,
    required this.narrowMobile,
    required this.isPlaying,
    required this.isPaused,
    required this.isConnecting,
    required this.isLiveMode,
    required this.showStoppedWhenIdle,
    required this.onCentralTap,
    required this.onLiveTap,
  });

  final double scale;
  final double playVisualSize;
  final bool narrowMobile;
  final bool isPlaying;
  final bool isPaused;
  /// Ligação ao stream ou buffer (ecrã de espera + ícone de carregar no play).
  final bool isConnecting;
  final bool isLiveMode;
  /// [idle] com erro de stream: mesmo ícone de **pausa** que durante a escuta (toque = retry).
  final bool showStoppedWhenIdle;
  final VoidCallback onCentralTap;
  /// Null quando não há sessão de escuta (idle ou a ligar ao stream).
  final VoidCallback? onLiveTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Controlo de reprodução: tocar ou pausar à esquerda, directo à direita',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayButton(
            isPlaying: isPlaying,
            isLoading: isConnecting,
            showStoppedWhenIdle: showStoppedWhenIdle,
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
            narrowMobile: narrowMobile,
          ),
        ],
      ),
    );
  }
}
