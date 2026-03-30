import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/live_mode_button.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

/// Comprimido cinza: **live** (sinal) à esquerda, **play/pause** à direita; centro vazio.
class RadioTransportControls extends StatelessWidget {
  const RadioTransportControls({
    super.key,
    required this.scale,
    required this.playVisualSize,
    required this.isOffline,
    required this.playbackLifecycle,
    required this.isPlaying,
    required this.isPaused,
    required this.isBuffering,
    required this.isPreparing,
    required this.isLiveMode,
    required this.isLiveReloading,
    required this.onTransportTap,
    required this.onLiveTap,
    this.onOfflineRestartApp,
    this.recoveryUiActive = false,
    this.refreshRestartsEntireApp = true,
  });

  final double scale;
  final double playVisualSize;
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
  /// Religar ao direto em curso — spinner no disco (TuneIn / [liveReloadInFlight]).
  final bool isLiveReloading;
  /// Botão play/pause — só transporte ([RadioPlayerUiNotifier.transportTap]).
  final VoidCallback onTransportTap;
  /// Botão live — só modo direct ([RadioPlayerUiNotifier.liveTap]); null se indisponível.
  final VoidCallback? onLiveTap;

  /// Sem leitura activa: reiniciar a app (ícone actualizar); o pai define quando (offline, erro, …).
  final VoidCallback? onOfflineRestartApp;

  /// True quando [isOffline] ou erro: o refresh prevalece sobre o indicador de load.
  final bool recoveryUiActive;

  /// Se false, o ícone refresh representa religar o fluxo (online), não [Restart] do processo.
  final bool refreshRestartsEntireApp;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final showRestartTransport = onOfflineRestartApp != null &&
        (!isBuffering || recoveryUiActive);
    final playEnabled =
        !isOffline || isPlaying || isBuffering || showRestartTransport;

    final vInset = AppSpacing.gHalf(scale);
    final hInset = AppSpacing.g(1, scale);
    final trackHeight = playVisualSize + vInset * 2;
    // Espaço cinza entre os discos; largura intrínseca para poder centrar no ecrã.
    final middleGap = math.max(
      AppSpacing.g(5, scale),
      playVisualSize * 1.15,
    );

    return Semantics(
      container: true,
      label: isOffline || showRestartTransport
          ? (refreshRestartsEntireApp
              ? kBibleFmSemanticsTransportRecoveryRestart
              : kBibleFmSemanticsTransportRecoveryReconnect)
          : kBibleFmSemanticsTransportNormal,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.transportCapsuleTrack(brightness),
          borderRadius: BorderRadius.circular(trackHeight / 2),
          border: Border.all(
            color: AppTheme.transportLiveBorder(brightness)
                .withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.5),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(hInset, vInset, hInset, vInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveModeButton(
                playbackLifecycle: playbackLifecycle,
                isLiveMode: isLiveMode,
                isPaused: isPaused,
                isOffline: isOffline,
                isLiveReloading: isLiveReloading,
                onPressed: onLiveTap,
                scale: scale,
                size: playVisualSize,
              ),
              SizedBox(width: middleGap),
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
            ],
          ),
        ),
      ),
    );
  }
}
