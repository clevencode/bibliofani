/// Textos visíveis e de acessibilidade — leitor Web.
library;

// --- Página ---
const String kBibleFmSemanticsPlayerPage = 'Bibliofani, leitor de rádio';

// --- Web: feedback + live (français) — minuscules, ultra court ---
const String kBibleFmWebFrFeedbackReloading = 'connexion…';
const String kBibleFmWebFrFeedbackBuffering = 'chargement…';
const String kBibleFmWebFrFeedbackLive = 'direct';
const String kBibleFmWebFrFeedbackListening = 'écoute';
const String kBibleFmWebFrFeedbackPaused = 'pause';
const String kBibleFmWebFrFeedbackReady = 'prêt';

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

// --- Web: lecteur HTML natif (`<audio controls>`) ---
/// Attribut [aria-label] sur l’élément `<audio>` (lecteurs d’écran).
const String kBibleFmWebFrNativeAudioAriaLabel =
    'Bibliofani, flux audio en direct';

/// Semantics Flutter autour du [HtmlElementView] (complement au natif).
const String kBibleFmWebFrNativeAudioSemanticsLabel =
    'Contrôles audio du navigateur pour Bibliofani';
const String kBibleFmWebFrNativeAudioSemanticsHint =
    'Lecture, pause et barre de progression sont fournis par votre navigateur.';

// --- Web: sleep timer ---
const String kBibleFmWebFrSleepA11y = 'Minuteur de sommeil';
const String kBibleFmWebFrSleepTooltip = 'Arrêter la lecture après…';
const String kBibleFmWebFrSleepOff = 'Minuteur désactivé';
const String kBibleFmWebFrSleepInputHint = 'Saisir la durée';
const String kBibleFmWebFrSleepPlaceholderDigits = '00';
const String kBibleFmWebFrSleepLabelHeure = 'heure';
const String kBibleFmWebFrSleepLabelMinute = 'minute';

// --- Web: saut ±10 s (barre sous la capsule) ---
const String kBibleFmWebFrSeekBack10Semantics = 'Reculer de 10 secondes';
const String kBibleFmWebFrSeekBack10Tooltip = 'Reculer de 10 secondes';
const String kBibleFmWebFrSeekForward10Semantics = 'Avancer de 10 secondes';
const String kBibleFmWebFrSeekForward10Tooltip = 'Avancer de 10 secondes';
