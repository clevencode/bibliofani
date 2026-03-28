import 'package:meu_app/features/radio/radio_stream_config.dart';

/// Estados apenas para a UI (sem backend de áudio).
///
/// **Carregamento do transporte:** [preparing] (loading no player) e [buffering]
/// (a encher buffer antes de reprodução estável). Fora destes, não há load activo.
enum UiPlaybackLifecycle {
  idle,
  preparing,
  buffering,
  playing,
  paused,
}

/// `true` enquanto o transporte está a **carregar** ou a **bufferizar** o fluxo.
bool isTransportLoadingUiLifecycle(UiPlaybackLifecycle lifecycle) {
  return lifecycle == UiPlaybackLifecycle.preparing ||
      lifecycle == UiPlaybackLifecycle.buffering;
}

/// Linha de estado na notificação de média / lock screen (alinhada à UI do leitor).
String bibleFmMediaNotificationStatusLine({
  required UiPlaybackLifecycle lifecycle,
  required bool isLiveMode,
}) {
  final playing = lifecycle == UiPlaybackLifecycle.playing;
  final loading = isTransportLoadingUiLifecycle(lifecycle);
  if (playing && !loading && isLiveMode) {
    return kBibleFmMediaNotificationLineDirect;
  }
  if (playing || loading) {
    return kBibleFmMediaNotificationLineEcoute;
  }
  return kBibleFmMediaNotificationLinePause;
}

