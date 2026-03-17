/// Endpoint principal do stream.
const String kRadioStreamUrl = 'https://servidor13.brlogic.com:7156/live';

/// Pool de endpoints para balanceamento/failover.
/// Mantenha o principal na primeira posicao.
const List<String> kRadioStreamCandidateUrls = [
  kRadioStreamUrl,
];
