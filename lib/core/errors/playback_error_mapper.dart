/// Mensagens estáveis para a UI (comparar em [RadioPlayerUiState.errorKind]).
class RadioUserMessages {
  RadioUserMessages._();

  static const offlinePlayback =
      'Sem ligação à Internet. Verifica o Wi‑Fi ou os dados móveis.';

  static const streamPlaybackFailed =
      'Não foi possível ligar ao stream. Tenta de novo dentro de instantes.';
}

enum PlaybackErrorKind {
  /// Sem interface de rede ou falha claramente de rede ao ligar ao stream.
  offline,

  /// Outros erros (servidor, formato, etc.).
  generic,
}

/// Resultado amigável para o utilizador + classificação.
typedef PlaybackFailure = ({String message, PlaybackErrorKind kind});

PlaybackFailure mapPlaybackFailure(Object error) {
  if (_looksLikeNetworkError(error)) {
    return (
      message: RadioUserMessages.offlinePlayback,
      kind: PlaybackErrorKind.offline,
    );
  }
  return (
    message: RadioUserMessages.streamPlaybackFailed,
    kind: PlaybackErrorKind.generic,
  );
}

bool _looksLikeNetworkError(Object error) {
  final blob = '${error.runtimeType} ${error.toString()}'.toLowerCase();
  if (blob.contains('socketexception')) return true;
  if (blob.contains('clientexception')) return true;
  if (blob.contains('httpexception')) return true;
  if (blob.contains('failed host lookup')) return true;
  if (blob.contains('network is unreachable')) return true;
  if (blob.contains('no address associated with hostname')) return true;
  if (blob.contains('connection refused')) return true;
  if (blob.contains('connection reset')) return true;
  if (blob.contains('connection timed out')) return true;
  if (blob.contains('timed out')) return true;
  if (blob.contains('tempo esgotado')) return true;
  if (blob.contains('network')) return true;
  if (blob.contains('internet')) return true;
  if (blob.contains('offline')) return true;
  if (blob.contains('errno = 7')) return true;
  if (blob.contains('errno = 8')) return true;
  if (blob.contains('errno = 101')) return true;
  if (blob.contains('errno = 103')) return true;
  if (blob.contains('errno = 110')) return true;
  if (blob.contains('platformexception')) {
    if (blob.contains('ioexception')) return true;
  }
  return false;
}
