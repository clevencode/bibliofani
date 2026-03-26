import 'package:flutter/material.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/live_mode_button.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

/// Barra inferior: **play** circular à esquerda, **live** em pílula à direita.
class RadioTransportControls extends StatelessWidget {
  const RadioTransportControls({
    super.key,
    required this.scale,
    required this.playVisualSize,
    required this.narrowMobile,
    required this.isOffline,
    required this.playbackLifecycle,
    required this.isPlaying,
    required this.isPaused,
    required this.isBuffering,
    required this.isPreparing,
    required this.isLiveMode,
    required this.onTransportTap,
    required this.onLiveTap,
    this.onOfflineRestartApp,
    this.recoveryUiActive = false,
    this.refreshRestartsEntireApp = true,
  });

  final double scale;
  final double playVisualSize;
  final bool narrowMobile;
  /// Sem interface de rede: limita play (exceto pausa / cancelar buffer) e direct.
  final bool isOffline;
  /// Ordem dos estados: idle → preparar → buffer → play/pause; direct só após fluxo.
  final UiPlaybackLifecycle playbackLifecycle;
  final bool isPlaying;
  final bool isPaused;
  /// [preparing] ou [buffering] — ver [isTransportLoadingUiLifecycle].
  final bool isBuffering;
  /// Só [preparing] (antes de [buffering]) — texto distinto no botão play.
  final bool isPreparing;
  final bool isLiveMode;
  /// Botão play/pause — só transporte ([RadioPlayerUiNotifier.transportTap]).
  final VoidCallback onTransportTap;
  /// Botão live — só modo direct ([RadioPlayerUiNotifier.liveTap]); null se indisponível.
  final VoidCallback? onLiveTap;

  /// Sem leitura activa: reiniciar a app (ícone atualizar); o pai define quando (offline, erro, …).
  final VoidCallback? onOfflineRestartApp;

  /// True quando [isOffline] ou erro: o refresh prevalece sobre o indicador de load.
  final bool recoveryUiActive;

  /// Se false, o ícone refresh representa religar o fluxo (online), não [Restart] do processo.
  final bool refreshRestartsEntireApp;

  @override
  Widget build(BuildContext context) {
    // Refresh visível offline/erro também durante preparing/buffering.
    final showRestartTransport = onOfflineRestartApp != null &&
        (!isBuffering || recoveryUiActive);
    final playEnabled =
        !isOffline || isPlaying || isBuffering || showRestartTransport;

    return Semantics(
      container: true,
      label: isOffline || showRestartTransport
          ? (refreshRestartsEntireApp
                ? 'Contrôles : pause, annuler le chargement, ou reiniciar a app si besoin'
                : 'Contrôles : pause, annuler le chargement, ou reconectar ao fluxo')
          : 'Ordre : lecture ou pause, puis direct à droite une fois le flux prêt',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayButton(
            isPlaying: isPlaying,
            isLoading: isBuffering,
            isPreparing: isPreparing,
            onTap: onTransportTap,
            size: playVisualSize,
            layoutScale: scale,
            enabled: playEnabled,
            isOffline: isOffline,
            onOfflineRestartApp: onOfflineRestartApp,
            recoveryUiActive: recoveryUiActive,
            refreshRestartsEntireApp: refreshRestartsEntireApp,
          ),
          LiveModeButton(
            playbackLifecycle: playbackLifecycle,
            isLiveMode: isLiveMode,
            isPaused: isPaused,
            isOffline: isOffline,
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
