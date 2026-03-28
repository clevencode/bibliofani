/// URL público do stream ao vivo (Icecast / SHOUTcast via BRLOGIC).
const String kBibleFmLiveStreamUrl =
    'https://servidor13.brlogic.com:7156/live';

/// ID do canal de notificação de média. **Alterar** força canal novo nas definições
/// (útil após mudanças de importância / nome). v2: alinhado a leitura em segundo plano.
const String kAndroidRadioNotificationChannelId =
    'com.exemplo.meu_app.channel.media_playback_v2';

/// Nome do canal nas definições Android (Notificações → Bible FM).
const String kAndroidRadioNotificationChannelName = 'Bible FM — Áudio';

/// Texto de ajuda no ecrã de canais do sistema.
const String kAndroidRadioNotificationChannelDescription =
    'Controlos de reprodução (play, pausa, direto) e leitura em segundo plano.';

/// Identificador estável do item de média (Android Auto / histórico de sessão).
const String kBibleFmMediaItemId = 'com.exemplo.meu_app.radio.live';

/// Ícone **pequeno** da barra de estado: vector monocromático branco (Material / Android).
/// Não usar o logótipo colorido aqui — o SO aplica tint e fica ilegível.
const String kAndroidMediaNotificationIcon = 'drawable/ic_stat_audio';

/// Metadados no MediaStyle / MediaSession (título fixo; subtítulo = estado de leitura).
///
/// Boas práticas: manter [kBibleFmMediaItemId] estável entre versões (histórico Auto);
/// textos curtos para uma linha na notificação compacta.
const String kBibleFmNotificationTitle = 'Bible FM';
const String kBibleFmNotificationDescription = 'Rádio — transmissão contínua';

/// Subtítulo dinâmico na notificação — ver [bibleFmMediaNotificationStatusLine].
const String kBibleFmMediaNotificationLinePause = 'En pause';
const String kBibleFmMediaNotificationLineEcoute = 'En écoute';
const String kBibleFmMediaNotificationLineDirect = 'En direct';

/// Terceira linha / agrupamento em alguns leitores de sistema (Auto, ecrã de bloqueio).
const String kBibleFmNotificationAlbum = 'Ao vivo';

/// Categoria para browsing / classificadores de sistema (radio, podcast, etc.).
const String kBibleFmMediaGenre = 'Radio';

/// Intervalo declarado para acções de avanço/recuar na notificação (API > 0 exigida).
const Duration kAndroidMediaSeekSkipInterval = Duration(seconds: 15);
