/// Textos visíveis e de acessibilidade em **português** (UI, notificação, erros).
/// Uma única fonte evita mistura FR/PT e mantém chip + notificação alinhados.
library;

// --- Notificação de média / lock screen (subtítulo dinâmico) ---
const String kBibleFmMediaNotificationLinePause = 'Em pausa';
const String kBibleFmMediaNotificationLineEcoute = 'A ouvir';
const String kBibleFmMediaNotificationLineDirect = 'Em direto';

// --- Pílula de estado no cartão do leitor ---
const String kBibleFmStatusChipOffline = 'Sem rede';
const String kBibleFmStatusChipError = 'Erro';
const String kBibleFmStatusChipLive = 'Em direto';
const String kBibleFmStatusChipListening = 'A ouvir';
const String kBibleFmStatusChipPaused = 'Em pausa';

// --- Erros (provider + banners) ---
const String kBibleFmErrorStream = 'Erro no fluxo. Tente novamente.';
const String kBibleFmErrorSecurity = 'Erro de segurança. Tente mais tarde.';
const String kBibleFmErrorUnreachable = 'Servidor inacessível. Tente novamente.';
const String kBibleFmErrorTimeout = 'Tempo esgotado. Tente novamente.';
/// Web: política de autoplay / gesto do utilizador no navegador.
const String kBibleFmErrorWebPlayback =
    'O navegador bloqueou o áudio. Toque outra vez em reproduzir.';
const String kBibleFmErrorBannerHint =
    'Verifique a ligação ou tente novamente.';
const String kBibleFmConnectivityLost =
    'Sem ligação — retoma automática quando voltar a rede.';

// --- Leitor: página ---
const String kBibleFmSemanticsPlayerPage = 'Bible FM, leitor de rádio';

// --- Web: feedback dinâmico no título (substitui texto estático) ---
const String kBibleFmWebFeedbackReady = 'Pronto para ouvir';
const String kBibleFmWebFeedbackBuffering = 'A carregar o fluxo…';

// --- Transporte (barra inferior) ---
const String kBibleFmSemanticsTransportRecoveryRestart =
    'Controlos: pausa, cancelar carregamento ou reiniciar a app';
const String kBibleFmSemanticsTransportRecoveryReconnect =
    'Controlos: pausa, cancelar carregamento ou voltar a ligar ao fluxo';
const String kBibleFmSemanticsTransportNormal =
    'Ordem: reproduzir ou pausar; em seguida direto à direita quando o fluxo estiver pronto';

// --- Botão play ---
const String kBibleFmPlayA11yOffline = 'Reprodução indisponível sem rede';
const String kBibleFmPlayA11yPause = 'Pausar reprodução';
const String kBibleFmPlayTooltipPause = 'Pausa';
const String kBibleFmPlayA11yStart = 'Iniciar reprodução';
const String kBibleFmPlayTooltipStart = 'Reproduzir';

// --- Botão direto ---
const String kBibleFmLiveA11yOffline = 'Direto indisponível sem rede';
const String kBibleFmLiveTooltipOffline = 'Sem ligação à Internet';
const String kBibleFmLiveA11yWaitStabilize = 'Direto após o fluxo estabilizar';
const String kBibleFmLiveTooltipWaitStabilize =
    'Aguarde o fluxo estabilizar antes do direto';
const String kBibleFmLiveA11yAfterStart = 'Direto após iniciar a leitura';
const String kBibleFmLiveTooltipAfterStart =
    'Inicie a leitura antes de activar o direto';
const String kBibleFmLiveA11yActive = 'Direto activo';
const String kBibleFmLiveTooltipActive = 'Direto activo';
const String kBibleFmLiveA11yCatchUp = 'Aproximar o contador do direto';
const String kBibleFmLiveTooltipCatchUp =
    'Aproxima o contador do direto sem repor a zero (repetir após pausa)';
const String kBibleFmLiveA11yGoLive = 'Ouvir em direto';
const String kBibleFmLiveTooltipGoLive = 'Ouvir em direto';
const String kBibleFmLiveA11yReloading = 'A religar ao direto…';
const String kBibleFmLiveTooltipReloading = 'A ligar ao fluxo em direto…';
const String kBibleFmLiveA11yPauseToEnable =
    'Direto: pausar a reprodução para activar';
const String kBibleFmLiveTooltipPauseToEnable =
    'Pausar a reprodução para poder ouvir em direto';

// --- Indicador pulsante (directo / diferido) ---
const String kBibleFmPulseTooltipDeferred =
    'Reprodução em diferido (não em direto)';
const String kBibleFmPulseTooltipFixed =
    'Sinal em direto (fixo). Passe a em direto para animar.';
const String kBibleFmPulseTooltipStopAnim = 'Toque para parar a animação do sinal';
const String kBibleFmPulseTooltipStartAnim =
    'Toque para animar o sinal em direto';
const String kBibleFmPulseA11yPaused = 'Indicador em pausa';
const String kBibleFmPulseA11yDeferred = 'Indicador em diferido, não em direto';
const String kBibleFmPulseA11yLiveFixed = 'Indicador em direto, sinal fixo';
const String kBibleFmPulseA11yLiveAnimated = 'Sinal em direto animado';
const String kBibleFmPulseHintStopAnim = 'Toque para parar a animação';
const String kBibleFmPulseA11yLive = 'Sinal em direto';
const String kBibleFmPulseHintStartAnim = 'Toque para activar a animação';
