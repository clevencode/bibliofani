/// Estados apenas para a UI (sem backend de áudio).
enum UiPlaybackLifecycle {
  idle,
  preparing,
  buffering,
  playing,
  paused,
}

bool isBufferingUiLifecycle(UiPlaybackLifecycle lifecycle) {
  return lifecycle == UiPlaybackLifecycle.preparing ||
      lifecycle == UiPlaybackLifecycle.buffering;
}
