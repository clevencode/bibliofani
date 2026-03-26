/// Ciclo de vida do leitor na UI (uma fase de cada vez).
///
/// **Fluxo**
/// 1. **Entrada** — arranque automático ou toque em play; passa a [connecting] enquanto o stream não está estável.
/// 2. **Processamento** — o [AudioPlayer] notifica estados; a UI segue com [connecting] → [playing] / [paused].
/// 3. **Saída** — [playing] / [paused] + bandeiras “live” alimentam som, notificação e widgets.
///
/// **Recarregamento** — Nova ligação após erro ou “parar”: o notifier faz `stop`, limpa a fonte carregada e volta a
/// [idle]; um novo play volta a `setAudioSource` + `play`. Operações assíncronas sobrepostas são descartadas via
/// epoch no [RadioPlayerUiNotifier] (ver implementação).
enum UiPlaybackLifecycle {
  idle,
  /// À espera da ligação ao servidor ou de buffer (antes de soar de forma estável).
  connecting,
  playing,
  paused,
}

/// True durante a fase em que ainda não há reprodução estável (ligação / buffer).
bool isConnectingLifecycle(UiPlaybackLifecycle lifecycle) {
  return lifecycle == UiPlaybackLifecycle.connecting;
}
