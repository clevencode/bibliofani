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

