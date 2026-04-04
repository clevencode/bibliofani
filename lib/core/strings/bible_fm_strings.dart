/// Textos visíveis e de acessibilidade — leitor Web.
library;

const String kBibleFmSemanticsPlayerPage = 'bibleco, lecteur radio';

const String kBibleFmWebFrFeedbackReloading = 'connexion…';
const String kBibleFmWebFrFeedbackBuffering = 'chargement…';
const String kBibleFmWebFrFeedbackLive = 'direct';
const String kBibleFmWebFrFeedbackListening = 'écoute';
const String kBibleFmWebFrFeedbackPaused = 'pause';
const String kBibleFmWebFrFeedbackReady = 'prêt';

/// Chrome / OS media hub (Media Session API) — alinhado ao feedback do leitor.
const String kBibleFmMediaSessionTitle = 'bibleco';
const String kBibleFmMediaSessionAlbum = 'Radio biblique';

/// Pause alors qu’on était au direct : combien le flux a avancé sur le serveur.
const String kBibleFmWebFrPauseLiveDriftTitle =
    'Antenne avancée pendant la pause';
const String kBibleFmWebFrPauseLiveDriftHint =
    'Le direct continue sur le serveur. Reprenez la lecture ou rapprochez-vous du « maintenant » sur la barre.';

/// Rappel d’interaction (barre HTML native + sauts ±10 s, fenêtre logique ~10 s près du direct).
const String kBibleFmWebFrListenBufferScrubHint =
    'Glissez ou utilisez ±10 s pour reculer ou rattraper le direct (environ 10 secondes près du « maintenant », selon le navigateur). Au-delà, retour au direct.';
const String kBibleFmWebFrLiveA11yReloading = 'Reconnexion au direct…';
const String kBibleFmWebFrLiveTooltipReloading = 'Connexion au flux en direct…';
const String kBibleFmWebFrLiveA11yActive = 'Direct actif';
const String kBibleFmWebFrLiveTooltipActive = 'Direct actif';
const String kBibleFmWebFrLiveA11yGoLive = 'Écouter le direct';
const String kBibleFmWebFrLiveTooltipGoLive = 'Écouter le direct';
const String kBibleFmWebFrLiveA11yPauseToEnable =
    'Direct : mettre la lecture en pause pour activer';
const String kBibleFmWebFrLiveTooltipPauseToEnable =
    'Mettre en pause pour pouvoir aller au direct';

/// A11y zone fond : tap = lecture/pause ; long press = direct (aligné bouton live).
const String kBibleFmWebFrBackgroundGestureA11y =
    'Fond d’écran : touche rapide lecture ou pause ; appui prolongé aller au direct';

/// Attribut [aria-label] sur l’élément `<audio>` (lecteurs d’écran).
const String kBibleFmWebFrNativeAudioAriaLabel =
    'bibleco, flux audio en direct';

/// Semantics Flutter autour du [HtmlElementView] (complement au natif).
const String kBibleFmWebFrNativeAudioSemanticsLabel =
    'Contrôles audio du navigateur pour bibleco';
const String kBibleFmWebFrNativeAudioSemanticsHint =
    'Lecture, pause et barre de progression sont fournis par votre navigateur.';

const String kBibleFmWebFrSleepA11y = 'Minuteur de sommeil';
const String kBibleFmWebFrSleepTooltip = 'Arrêter la lecture après…';
const String kBibleFmWebFrSleepInputHint = 'Saisir la durée';
const String kBibleFmWebFrSleepPlaceholderDigits = '00';
const String kBibleFmWebFrSleepLabelHeure = 'heure';
const String kBibleFmWebFrSleepLabelMinute = 'minute';
const String kBibleFmWebFrSleepApplySemantics = 'Valider le minuteur';
const String kBibleFmWebFrSleepApplyTooltip = 'Démarrer le minuteur';
const String kBibleFmWebFrSleepCloseSemantics = 'Fermer la configuration du minuteur';
const String kBibleFmWebFrSleepCloseTooltip = 'Fermer';

const String kBibleFmWebFrSeekBack10Semantics = 'Reculer de 10 secondes';
const String kBibleFmWebFrSeekBack10Tooltip = 'Reculer de 10 secondes';
const String kBibleFmWebFrSeekForward10Semantics = 'Avancer de 10 secondes';
const String kBibleFmWebFrSeekForward10Tooltip = 'Avancer de 10 secondes';
