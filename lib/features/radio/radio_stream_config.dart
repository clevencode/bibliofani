/// URL público do stream ao vivo (Icecast / SHOUTcast via BRLOGIC).
const String kBibleFmLiveStreamUrl =
    'https://servidor13.brlogic.com:7156/live';

/// Identificadores estáveis do canal de notificação Android (segundo plano).
const String kAndroidRadioNotificationChannelId =
    'com.exemplo.meu_app.channel.audio';

const String kAndroidRadioNotificationChannelName = 'Bible FM';

/// Descrição do canal (definições do sistema → notificações → Bible FM).
const String kAndroidRadioNotificationChannelDescription =
    'Controlos de reprodução e leitura em segundo plano.';

/// Identificador estável do item de média (Android Auto / histórico de sessão).
const String kBibleFmMediaItemId = 'com.exemplo.meu_app.radio.live';

/// Ícone da notificação: vector branco transparente (`res/drawable/…`), formato exigido pelo MediaStyle.
const String kAndroidMediaNotificationIcon = 'drawable/ic_stat_audio';

/// Metadados apresentados no MediaStyle (título, subtítulo, terceira linha).
const String kBibleFmNotificationTitle = 'Bible FM';
const String kBibleFmNotificationArtist = 'En direct';
const String kBibleFmNotificationDescription = 'Rádio — transmissão contínua';

/// Categoria para browsing / classificadores de sistema (radio, podcast, etc.).
const String kBibleFmMediaGenre = 'Radio';

/// Intervalo declarado para acções de avanço/recuar na notificação (API > 0 exigida).
const Duration kAndroidMediaSeekSkipInterval = Duration(seconds: 15);
