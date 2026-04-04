// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:bibliofani/core/strings/bible_fm_strings.dart';

/// Tempos centralizados (spinner, esperas de buffer no live).
const _kWebCanPlayTimeout = Duration(seconds: 10);
const _kWebPlayStartTimeout = Duration(seconds: 12);
const _kWebLiveSpinnerMin = Duration(milliseconds: 280);
const _kWebSkipSeekAfterLiveReload = Duration(seconds: 4);

/// Após pausa mais longa que isto, ao dar **play** religa ao servidor com URL nova
/// (busting + `load()`), evitando ligações HTTP antigas Icecast/servidor e buffer morto.
const _kWebStaleResumeReconnectAfter = Duration(minutes: 30);

/// Deteção UI «próximo do directo» (feedback, botão live).
const double _kWebLiveEdgeBufferMarginSec = 2.5;

/// Tecto de `currentTime` relativamente a [buffered.end]: não ultrapassar o «agora» do tampon
/// (evita scrub/reprodução «além» do live e atraso artificial).
const double _kWebScrubLiveCeilingEpsilonSec = 0.12;

/// Tolerância numérica: acima disto em relação ao teto live → seek imediato ao teto (barra / buffer).
const double _kWebLiveCeilingOverrunSnapSec = 1e-5;

/// Enquanto «em directo» e a reproduzir, revalida o teto live a este ritmo (timeupdate sozinho pode ser ~250 ms).
const Duration _kWebLiveCeilingGuardInterval = Duration(milliseconds: 32);

/// Janela lógica junto ao live: a app só considera os últimos [N] s de média para seeks, clamps e sync.
/// O browser pode manter mais dados em memória; sem MSE não se «apaga» o buffer real — isto limita trabalho e UI.
const double _kWebLogicalBufferWindowSec = 10.0;

html.AudioElement? _webBibleFmAudio;

/// Contentor do `HtmlElementView` dos controlos nativos (p.ex. `pointer-events` sob modal do sono).
html.DivElement? _webAudioControlsWrap;

/// URL base do fluxo (registada com o `<audio>`) — appui long no fundo e botão live.
String? _webLiveStreamBaseUrl;

/// Estilos para `::-webkit-media-controls-*`: fundo do painel nativo transparente (contorno fica no Flutter).
const _kAudioChromeStyleId = 'bibliofani-audio-chrome-style-v3';

/// Script injectado: o getter `duration` do `<audio class="bibliofani-native-audio">` devolve um valor
/// **finito** a partir de `buffered.end` (alinhado a [_kWebScrubLiveCeilingEpsilonSec]) em **play e pause**.
/// Assim a barra nativa do Chrome não permite arrastar «além» do bordo live (`duration` infinito no HLS/Icecast).
const _kLiveDurationHookScriptId = 'bibliofani-duration-hook-script-v3';

void _ensureLiveDurationHookScript() {
  if (html.document.getElementById(_kLiveDurationHookScriptId) != null) {
    return;
  }
  final script = html.ScriptElement()
    ..id = _kLiveDurationHookScriptId
    ..type = 'text/javascript'
    ..text = r'''
(function(w) {
  var HOOK_VER = 3;
  if (w.__bfmLiveDurHookVer === HOOK_VER) return;
  if (w.__bfmLiveDurTimer) {
    clearInterval(w.__bfmLiveDurTimer);
    w.__bfmLiveDurTimer = null;
  }
  w.__bfmLiveDurHookVer = HOOK_VER;
  try {
    var oldA = document.querySelector('.bibliofani-native-audio');
    if (oldA && oldA.__bfmDurationHooked) {
      delete oldA.duration;
      oldA.__bfmDurationHooked = false;
    }
  } catch (e0) {}
  var eps = 0.12;
  function bufEnd(a) {
    try {
      if (!a.buffered || a.buffered.length === 0) return NaN;
      return a.buffered.end(a.buffered.length - 1);
    } catch (e) { return NaN; }
  }
  function install(audio) {
    if (!audio || audio.__bfmDurationHooked) return;
    var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'duration');
    var nativeGet = desc && desc.get;
    if (!nativeGet) return;
    audio.__bfmDurationHooked = true;
    Object.defineProperty(audio, 'duration', {
      get: function() {
        var end = bufEnd(this);
        if (!(end > 0) || end !== end) {
          try { return nativeGet.call(this); } catch (e) { return NaN; }
        }
        var ct = 0;
        try { ct = Number(this.currentTime); } catch (e2) {}
        if (ct !== ct) ct = 0;
        var floor = end - eps;
        if (!(floor > 0)) {
          try { return nativeGet.call(this); } catch (e3) { return end; }
        }
        return Math.min(end, Math.max(floor, ct));
      },
      configurable: true,
      enumerable: true
    });
  }
  function tick() {
    var a = document.querySelector('.bibliofani-native-audio');
    if (!a) return;
    install(a);
  }
  tick();
  w.__bfmLiveDurTimer = setInterval(tick, 350);
})(window);
''';
  html.document.head?.append(script);
}

void _ensureAudioControlsChromeCss() {
  if (html.document.getElementById(_kAudioChromeStyleId) != null) {
    return;
  }
  final style = html.StyleElement()
    ..id = _kAudioChromeStyleId
    ..text = '''
.bibliofani-native-audio {
  background-color: transparent !important;
  color-scheme: dark !important;
  accent-color: #ffffff !important;
  color: #ffffff !important;
}
.bibliofani-native-audio::-webkit-media-controls-panel,
.bibliofani-native-audio::-webkit-media-controls-enclosure {
  background-color: rgba(0, 0, 0, 0) !important;
}
.bibliofani-native-audio::-webkit-media-controls-current-time-display,
.bibliofani-native-audio::-webkit-media-controls-time-remaining-display {
  color: #ffffff !important;
  text-shadow: none !important;
}
''';
  html.document.head?.append(style);
  _ensureLiveDurationHookScript();
}

/// Enquanto o configurador de sono está aberto: mantém a barra nativa **visível** (pré-visualização)
/// mas **sem toque** (`pointer-events: none`) para a outra camada (véu / temporizador) receber os gestos.
void bibleFmWebSetSleepConfiguratorOpen(bool open) {
  final w = _webAudioControlsWrap;
  if (w == null) return;
  if (open) {
    w.style.pointerEvents = 'none';
  } else {
    w.style.pointerEvents = '';
  }
}

ScrollController? _webScrollVertical;
ScrollController? _webScrollHorizontal;

/// Liga a roda do rato sobre o `<audio>` aos [SingleChildScrollView] Flutter (Web).
void bibleFmWebAttachScrollBridge(
  ScrollController? vertical,
  ScrollController? horizontal,
) {
  _webScrollVertical = vertical;
  _webScrollHorizontal = horizontal;
}

void bibleFmWebDetachScrollBridge() {
  _webScrollVertical = null;
  _webScrollHorizontal = null;
}

double _wheelDeltaScale(html.WheelEvent e) {
  if (e.deltaMode == 1) return 16.0;
  if (e.deltaMode == 2) {
    return html.window.innerHeight?.toDouble() ?? 600.0;
  }
  return 1.0;
}

bool _relayWheelToController(ScrollController? c, double delta) {
  if (c == null || !c.hasClients) return false;
  final p = c.position;
  if (p.maxScrollExtent <= p.minScrollExtent) return false;
  final next = (p.pixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent);
  if (next == p.pixels) return false;
  c.jumpTo(next);
  return true;
}

void _installWheelRelayOnAudioWrap(html.DivElement wrap) {
  wrap.onWheel.listen((html.WheelEvent e) {
    final scale = _wheelDeltaScale(e);
    var dy = e.deltaY.toDouble() * scale;
    var dx = e.deltaX.toDouble() * scale;
    if (e.shiftKey && dx.abs() < 0.01 && dy.abs() > 0.01) {
      dx = dy;
      dy = 0;
    }
    final preferHorizontal = dx.abs() > dy.abs() && dx.abs() > 0.01;
    final consumed = preferHorizontal
        ? _relayWheelToController(_webScrollHorizontal, dx)
        : (dy.abs() > 0.01 && _relayWheelToController(_webScrollVertical, dy));
    if (consumed) {
      e.preventDefault();
    }
  });
}

/// [Media Session](https://w3c.github.io/mediasession/): centro de média do SO, teclas físicas, notificação.
void _installWebMediaSession(html.AudioElement a) {
  final ms = html.window.navigator.mediaSession;
  if (ms == null) return;
  try {
    ms.metadata = html.MediaMetadata({
      'title': 'Bibliofani',
      'artist': 'En direct',
      'album': 'Radio',
    });
    // Estados em [Media Session standard](https://w3c.github.io/mediasession/#enumdef-mediasessionplaybackstate)
    ms.playbackState = 'none';
  } catch (_) {}

  void safePlay() => unawaited(a.play().catchError((Object? _) {}));

  void safePause() {
    try {
      a.pause();
    } catch (_) {}
  }

  try {
    ms.setActionHandler('play', () => safePlay());
    ms.setActionHandler('pause', safePause);
  } catch (_) {}
}

void _syncWebMediaSessionPlaybackState(html.AudioElement a) {
  final ms = html.window.navigator.mediaSession;
  if (ms == null) return;
  try {
    ms.playbackState = a.paused ? 'paused' : 'playing';
  } catch (_) {}
}

void _initWebAudioNotifiersAndMediaSession(html.AudioElement a) {
  _installWebMediaSession(a);
  _syncWebMediaSessionPlaybackState(a);
  _syncWebPlaybackNotifierFrom(a);
}

/// **Clique** no fundo: só [play] / [pause] no `<audio>` (não religa o direct).
void bibleFmWebBackgroundTapPlayPause() {
  final el = _webBibleFmAudio;
  if (el == null || bibleFmWebLiveReloading.value) return;
  if (el.paused) {
    unawaited(el.play().catchError((Object? _) {}));
  } else {
    try {
      el.pause();
    } catch (_) {}
  }
}

/// Pausa directa do `<audio>` (usado por sleep timer).
void bibleFmWebPausePlayback() {
  final el = _webBibleFmAudio;
  if (el == null) return;
  try {
    el.pause();
  } catch (_) {}
}

/// Saut ±[deltaSec] secondes, **borné à la fenêtre logique** [_kWebLogicalBufferWindowSec] près du live.
void bibleFmWebSeekRelativeSeconds(double deltaSec) {
  final a = _webBibleFmAudio;
  if (a == null || bibleFmWebLiveReloading.value) return;
  if (!bibleFmWebSessionEverStarted.value) return;
  if (!deltaSec.isFinite || deltaSec == 0) return;

  final end = _bufferedEndSec(a);
  if (end == null || !end.isFinite) return;
  final lo =
      _logicalBufferedStartSec(a) ?? math.max(0.0, _bufferedStartSec(a) ?? 0.0);
  final hiRaw = end - _kWebScrubLiveCeilingEpsilonSec;
  final hi = hiRaw.isFinite ? hiRaw : end;
  final minT = math.min(lo, hi);
  final maxT = math.max(lo, hi);

  final ct = a.currentTime;
  if (!ct.isFinite) return;
  final target = (ct + deltaSec).clamp(minT, maxT).toDouble();

  _webResyncSessionClockToSeconds(target, paused: a.paused);
  _webAssignCurrentTimeForSync(a, target);
  _webUpdateLiveEdgeFromBufferPosition(a);
  _syncNativeAudioElapsedDisplay();
}

/// **Appui long** no fundo: [bibleFmWebReloadLiveStream] — mesmas regras que o botão live
/// (inactif si déjà direct en lecture).
void bibleFmWebBackgroundLongPressGoLive() {
  final el = _webBibleFmAudio;
  if (el == null || bibleFmWebLiveReloading.value) return;
  final playing = !el.paused;
  final atLiveEdge = bibleFmWebLiveEdgeActive.value;
  if (playing && atLiveEdge) return;

  final base = _webLiveStreamBaseUrl;
  if (base == null) return;
  unawaited(bibleFmWebReloadLiveStream(base).catchError((Object? _) {}));
}

/// `true` enquanto o `<audio>` está a reproduzir (para opacidade do botão «live» na web).
final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);

/// `true` durante [bibleFmWebReloadLiveStream] — spinner no botão live (padrão TuneIn).
final bibleFmWebLiveReloading = ValueNotifier<bool>(false);

/// Depois de religar ao fluxo com sucesso: sincronizado com «já em directo» (desactiva live até pausa).
final bibleFmWebLiveEdgeActive = ValueNotifier<bool>(false);

/// `waiting` no `<audio>` (feedback no título).
final bibleFmWebBuffering = ValueNotifier<bool>(false);

/// `true` após o primeiro play (distingue pausa de «ainda não iniciou»).
final bibleFmWebSessionEverStarted = ValueNotifier<bool>(false);

/// Avanço do bordo live (`buffered.end`) desde a pausa feita **em directo** ; repõe ao dar play ou religar o live.
final bibleFmWebLiveMovedWhilePausedSec = ValueNotifier<double?>(null);

/// Referência `buffered.end` no instante da pausa a partir do directo.
double? _webBufferedEndAtPauseFromLive;

Timer? _webPauseLiveDriftTimer;

Timer? _webLiveCeilingRapidGuardTimer;

DateTime? _webPlayingSince;
Duration _webElapsedPriorSegments = Duration.zero;

/// Início da pausa actual (relógio de parede) — salto TuneIn ao tocar em live.
DateTime? _webPausedSince;
Timer? _webSessionTickTimer;

/// Após [src] novo + [play], evita «seek» para o tempo de sessão (>> buffer) que **parava** o áudio no Chrome.
DateTime? _webSkipSeekCoalesceUntil;

/// Cada `currentTime = …` feito pela sincronização do relógio dispara `seeked`; ignorar para não tratar como scrub do utilizador.
int _webProgrammaticTimelineSeekPending = 0;

/// Após a primeira pausa com sessão iniciada: [onPlaying] fica em **en écoute** (sem promover «direct»), até religação explícita ao live.
bool _webPreferListenModeAfterPause = false;

/// Após [bibleFmWebReloadLiveStream] com sucesso: [onPlaying] alinha «direct» pelo buffer até à **próxima** pausa.
bool _webForceBufferLiveEdgeOnPlaying = false;

double? _bufferedEndSec(html.AudioElement a) {
  final b = a.buffered;
  if (b.length == 0) return null;
  return b.end(b.length - 1);
}

double? _bufferedStartSec(html.AudioElement a) {
  final b = a.buffered;
  if (b.length == 0) return null;
  return b.start(0);
}

/// Início da janela lógica: `max(buffered.start, end − 10s)` quando o span excede 10 s.
/// Simula «só guardar ~10 s úteis» para lógica da app (sem cortar RAM do browser).
double? _logicalBufferedStartSec(html.AudioElement a) {
  final end = _bufferedEndSec(a);
  final start = _bufferedStartSec(a);
  if (end == null || start == null) return null;
  if (!end.isFinite || !start.isFinite) return null;
  final span = end - start;
  if (span <= _kWebLogicalBufferWindowSec) return start;
  return end - _kWebLogicalBufferWindowSec;
}

/// Limite seguro: nunca pedir `currentTime` além do bordo do buffer menos [epsilon] (live).
double _safeTargetCurrentTimeSec(html.AudioElement a, double sessionSec) {
  final end = _bufferedEndSec(a);
  if (end == null) return sessionSec;
  final cap = end - _kWebScrubLiveCeilingEpsilonSec;
  final lim = cap.isFinite && cap > 0 ? cap : end;
  var out = sessionSec <= lim ? sessionSec : lim;
  final lo = _logicalBufferedStartSec(a);
  if (lo != null && out + 1e-3 < lo) {
    out = lo;
  }
  return out;
}

/// Teto de reprodução junto ao directo: `buffered.end − ε` (alinhado ao scrub / hook de `duration`).
double? _webPlaybackLiveCeilingSec(html.AudioElement a) {
  final end = _bufferedEndSec(a);
  if (end == null || !end.isFinite) return null;
  final cap = end - _kWebScrubLiveCeilingEpsilonSec;
  if (cap.isFinite && cap > 0) return cap;
  return end;
}

void _webCancelLiveCeilingRapidGuard() {
  _webLiveCeilingRapidGuardTimer?.cancel();
  _webLiveCeilingRapidGuardTimer = null;
}

/// Modo direct + play: polling curto para não depender só do `timeupdate` ao colar no bordo do buffer.
void _webSyncLiveCeilingRapidGuardWithPlayback(html.AudioElement a) {
  if (a.paused || bibleFmWebLiveReloading.value) {
    _webCancelLiveCeilingRapidGuard();
    return;
  }
  if (!bibleFmWebLiveEdgeActive.value) {
    _webCancelLiveCeilingRapidGuard();
    return;
  }
  if (_webLiveCeilingRapidGuardTimer != null) return;
  _webLiveCeilingRapidGuardTimer = Timer.periodic(
    _kWebLiveCeilingGuardInterval,
    (_) {
      final el = _webBibleFmAudio;
      if (el == null ||
          el.paused ||
          el.seeking ||
          bibleFmWebLiveReloading.value ||
          !bibleFmWebLiveEdgeActive.value) {
        _webCancelLiveCeilingRapidGuard();
        return;
      }
      _webClampPlayingCurrentTimeToLiveCeiling(el);
    },
  );
}

/// Em **reprodução**, se a posição passar o limite live, repõe já o `currentTime` e o relógio de sessão.
void _webClampPlayingCurrentTimeToLiveCeiling(html.AudioElement a) {
  if (a.paused || a.seeking) return;
  final ceiling = _webPlaybackLiveCeilingSec(a);
  if (ceiling == null) return;
  final t = a.currentTime.toDouble();
  if (!t.isFinite || t <= ceiling + _kWebLiveCeilingOverrunSnapSec) return;
  _webResyncSessionClockToSeconds(ceiling, paused: false);
  _webProgrammaticTimelineSeekPending++;
  try {
    a.currentTime = ceiling;
  } catch (_) {
    if (_webProgrammaticTimelineSeekPending > 0) {
      _webProgrammaticTimelineSeekPending--;
    }
  }
  _webUpdateLiveEdgeFromBufferPosition(a);
}

void _webAssignCurrentTimeForSync(html.AudioElement a, double seekTo) {
  try {
    if ((a.currentTime - seekTo).abs() <= 0.035) return;
    _webProgrammaticTimelineSeekPending++;
    a.currentTime = seekTo;
  } catch (_) {
    if (_webProgrammaticTimelineSeekPending > 0) {
      _webProgrammaticTimelineSeekPending--;
    }
  }
}

/// Actualiza «em directo» conforme a posição no buffer (após scrub ou retoma após stall).
void _webUpdateLiveEdgeFromBufferPosition(html.AudioElement a) {
  final end = _bufferedEndSec(a);
  if (end == null) {
    bibleFmWebLiveEdgeActive.value = true;
    _webSyncLiveCeilingRapidGuardWithPlayback(a);
    return;
  }
  final atLive =
      (end - a.currentTime) <= _kWebLiveEdgeBufferMarginSec;
  bibleFmWebLiveEdgeActive.value = atLive;
  if (atLive) {
    _webSyncLiveCeilingRapidGuardWithPlayback(a);
  } else {
    _webCancelLiveCeilingRapidGuard();
  }
}

void _webResyncSessionClockToSeconds(double t, {required bool paused}) {
  if (!t.isFinite || t < 0) return;
  _webElapsedPriorSegments = Duration(microseconds: (t * 1e6).round());
  if (!paused) {
    _webPlayingSince = DateTime.now();
  } else {
    _webPlayingSince = null;
  }
}

/// Alinha o relógio de sessão ao `currentTime` após o utilizador mover a barra (evita o timer anular o scrub).
void _webResyncSessionClockToAudioPosition(html.AudioElement a) {
  _webResyncSessionClockToSeconds(a.currentTime.toDouble(), paused: a.paused);
}

/// Se o browser permitir scrub fora do tampon Icecast, força [início lógico .. fin−ε] (nunca além do live).
double? _webScrubClampTargetSec(html.AudioElement a) {
  final end = _bufferedEndSec(a);
  final rawStart = _bufferedStartSec(a);
  final start = _logicalBufferedStartSec(a) ?? rawStart;
  if (start == null || end == null || rawStart == null) return null;
  var hi = end - _kWebScrubLiveCeilingEpsilonSec;
  if (!hi.isFinite || hi < start) hi = start;
  final t = a.currentTime.toDouble();
  if (!t.isFinite) return null;
  const eps = 0.06;
  if (t < start - eps) return start;
  if (t > hi + eps) return hi;
  return null;
}

void _onWebAudioSeeked(html.AudioElement a) {
  if (_webProgrammaticTimelineSeekPending > 0) {
    _webProgrammaticTimelineSeekPending--;
    return;
  }

  final clampTo = _webScrubClampTargetSec(a);
  if (clampTo != null) {
    _webResyncSessionClockToSeconds(clampTo, paused: a.paused);
    _webProgrammaticTimelineSeekPending++;
    try {
      a.currentTime = clampTo;
    } catch (_) {
      _webProgrammaticTimelineSeekPending--;
      return;
    }
    _webUpdateLiveEdgeFromBufferPosition(a);
    _syncNativeAudioElapsedDisplay();
    return;
  }

  _webResyncSessionClockToAudioPosition(a);
  _webUpdateLiveEdgeFromBufferPosition(a);
  _syncNativeAudioElapsedDisplay();
}

/// Expõe o tempo de sessão no `currentTime` do `<audio controls>` ; o hook JS de `duration` (play e pause)
/// fixa um teto finito em `buffered.end`, para o Chrome mostrar *posição / direct* e limitar o scrub ao live.
void _syncNativeAudioElapsedDisplay() {
  final a = _webBibleFmAudio;
  if (a == null) return;
  if (a.seeking) return;

  try {
    final sessionSec = _webSessionTotalElapsed().inMicroseconds / 1e6;
    if (!sessionSec.isFinite || sessionSec < 0) return;

    if (a.paused) {
      try {
        final bufEnd = _bufferedEndSec(a);
        if (bufEnd == null && sessionSec > 1.5) {
          return;
        }
        final target = _safeTargetCurrentTimeSec(a, sessionSec);
        if ((a.currentTime - target).abs() > 0.04) {
          _webAssignCurrentTimeForSync(a, target);
        }
      } catch (_) {}
      return;
    }

    if (_webSkipSeekCoalesceUntil != null &&
        DateTime.now().isBefore(_webSkipSeekCoalesceUntil!)) {
      return;
    }

    _webClampPlayingCurrentTimeToLiveCeiling(a);

    final bufEndPlaying = _bufferedEndSec(a);
    if (bufEndPlaying != null) {
      final sessionCeiling =
          bufEndPlaying - _kWebScrubLiveCeilingEpsilonSec + 0.08;
      if (sessionSec > sessionCeiling) {
        _webClampPlayingCurrentTimeToLiveCeiling(a);
        return;
      }
    }

    final target = _safeTargetCurrentTimeSec(a, sessionSec);
    final drift = (target - a.currentTime).abs();
    // Junto ao directo: corrigir desalinhamento cedo (barra / relógio de sessão), não só com >1,15 s.
    final tightDriftCap =
        bibleFmWebLiveEdgeActive.value ? 0.12 : 1.15;
    if (drift <= tightDriftCap) return;
    _webAssignCurrentTimeForSync(a, target);
  } catch (_) {}
}

void _syncWebPlaybackNotifierFrom(html.AudioElement a) {
  bibleFmWebPlaybackActive.value = !a.paused;
}

void _webFoldPlayingSegment() {
  final start = _webPlayingSince;
  if (start != null) {
    _webElapsedPriorSegments += DateTime.now().difference(start);
    _webPlayingSince = null;
  }
}

Duration _webSessionTotalElapsed() {
  var t = _webElapsedPriorSegments;
  final start = _webPlayingSince;
  if (start != null) {
    t += DateTime.now().difference(start);
  }
  return t;
}

void _webStartSessionTick() {
  _webSessionTickTimer?.cancel();
  _webSessionTickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
    _syncNativeAudioElapsedDisplay();
  });
}

void _webStopSessionTick() {
  _webSessionTickTimer?.cancel();
  _webSessionTickTimer = null;
  _syncNativeAudioElapsedDisplay();
}

void _webClearPauseFromLiveDrift() {
  _webBufferedEndAtPauseFromLive = null;
  bibleFmWebLiveMovedWhilePausedSec.value = null;
  _webPauseLiveDriftTimer?.cancel();
  _webPauseLiveDriftTimer = null;
}

void _webUpdateLiveMovedWhilePausedNotifier(html.AudioElement a) {
  final base = _webBufferedEndAtPauseFromLive;
  if (base == null || !base.isFinite || !a.paused) {
    bibleFmWebLiveMovedWhilePausedSec.value = null;
    return;
  }
  final end = _bufferedEndSec(a);
  if (end == null || !end.isFinite) {
    return;
  }
  bibleFmWebLiveMovedWhilePausedSec.value = (end - base).clamp(0.0, 86400.0);
}

void _webStartPauseLiveDriftTimer() {
  _webPauseLiveDriftTimer?.cancel();
  _webPauseLiveDriftTimer = Timer.periodic(const Duration(milliseconds: 500), (
    _,
  ) {
    final el = _webBibleFmAudio;
    if (el == null || !el.paused || _webBufferedEndAtPauseFromLive == null) {
      _webPauseLiveDriftTimer?.cancel();
      _webPauseLiveDriftTimer = null;
      return;
    }
    _webUpdateLiveMovedWhilePausedNotifier(el);
  });
}

void _onWebAudioPlay(html.AudioElement a) {
  final pausedSince = _webPausedSince;
  if (pausedSince != null &&
      DateTime.now().difference(pausedSince) >=
          _kWebStaleResumeReconnectAfter) {
    final base = _webLiveStreamBaseUrl;
    if (base != null && !bibleFmWebLiveReloading.value) {
      unawaited(bibleFmWebReloadLiveStream(base).catchError((Object? _) {}));
      return;
    }
  }

  _webClearPauseFromLiveDrift();

  bibleFmWebSessionEverStarted.value = true;
  // Primeiro play / rede lenta: onPlay pode disparar antes de haver dados; não esconder «chargement» cedo demais.
  bibleFmWebBuffering.value =
      a.readyState < html.MediaElement.HAVE_CURRENT_DATA;
  _webPlayingSince ??= DateTime.now();
  _webPausedSince = null;
  _syncWebPlaybackNotifierFrom(a);
  _syncWebMediaSessionPlaybackState(a);
  _webStartSessionTick();
  _syncNativeAudioElapsedDisplay();
}

void _onWebAudioPauseOrEnd(html.AudioElement a) {
  _webCancelLiveCeilingRapidGuard();
  final wasAtLiveEdge =
      bibleFmWebLiveEdgeActive.value && !bibleFmWebLiveReloading.value;
  bibleFmWebBuffering.value = false;
  bibleFmWebLiveEdgeActive.value = false;
  _webForceBufferLiveEdgeOnPlaying = false;
  if (bibleFmWebSessionEverStarted.value) {
    _webPreferListenModeAfterPause = true;
  }
  _webFoldPlayingSegment();
  _webPausedSince = DateTime.now();
  _webStopSessionTick();
  _syncWebPlaybackNotifierFrom(a);
  _syncWebMediaSessionPlaybackState(a);

  if (wasAtLiveEdge && bibleFmWebSessionEverStarted.value) {
    _webBufferedEndAtPauseFromLive = _bufferedEndSec(a);
  } else {
    _webBufferedEndAtPauseFromLive = null;
  }
  if (_webBufferedEndAtPauseFromLive != null) {
    _webUpdateLiveMovedWhilePausedNotifier(a);
    _webStartPauseLiveDriftTimer();
  } else {
    bibleFmWebLiveMovedWhilePausedSec.value = null;
    _webPauseLiveDriftTimer?.cancel();
    _webPauseLiveDriftTimer = null;
  }
}

/// Soma de uma vez o tempo em pausa ao contador (estilo TuneIn), sem contar em tempo real durante a pausa.
void _webApplyLiveElapsedJumpFromPausedWallClock() {
  final mark = _webPausedSince;
  if (mark == null) return;
  _webElapsedPriorSegments += DateTime.now().difference(mark);
  _webPausedSince = null;
  _syncNativeAudioElapsedDisplay();
}

Future<void> _webEnsureMinLiveSpinnerShown(DateTime started) async {
  final elapsed = DateTime.now().difference(started);
  if (elapsed < _kWebLiveSpinnerMin) {
    await Future<void>.delayed(_kWebLiveSpinnerMin - elapsed);
  }
}

/// Garante que o spinner cobre buffer + primeiro frame de áudio (TuneIn), não só a Promise do [play].
Future<void> _webAwaitPlayActuallyStarted(html.AudioElement el) async {
  if (!el.paused && el.readyState >= html.MediaElement.HAVE_CURRENT_DATA) {
    return;
  }
  try {
    await el.onPlay.first.timeout(_kWebPlayStartTimeout);
  } on TimeoutException {
    // Mantém coerência com o finally (spinner + edge).
  }
}

/// [play] com política de autoplay: sem gesto, browsers rejeitam som; **muted** costuma ser permitido.
/// Se o buffer ainda não está pronto após [load], repete após [canplay].
Future<void> _webPlayWithAutoplayPolicy(html.AudioElement el) async {
  Future<void> attemptPlay() async {
    try {
      await el.play();
      if (!el.paused) return;
    } catch (_) {}

    final wasMuted = el.muted;
    try {
      el.muted = true;
      await el.play();
    } finally {
      el.muted = wasMuted;
    }
  }

  await attemptPlay();
  if (el.paused) {
    try {
      await el.onCanPlay.first.timeout(_kWebCanPlayTimeout);
    } on TimeoutException {
      return;
    }
    if (!el.paused) return;
    await attemptPlay();
  }
}

/// Religa o fluxo ao instante actual e **inicia reprodução** (toque no live = gesto).
Future<void> bibleFmWebReloadLiveStream(String baseUrl) async {
  final el = _webBibleFmAudio;
  if (el == null) return;
  if (bibleFmWebLiveReloading.value) return;
  _webClearPauseFromLiveDrift();
  final spinnerStarted = DateTime.now();
  bibleFmWebLiveReloading.value = true;
  _webCancelLiveCeilingRapidGuard();
  try {
    _webApplyLiveElapsedJumpFromPausedWallClock();
    var uri = Uri.parse(baseUrl);
    final q = Map<String, String>.from(uri.queryParameters);
    q['_'] = DateTime.now().millisecondsSinceEpoch.toString();
    uri = uri.replace(queryParameters: q);
    el.src = uri.toString();
    el.load();
    _webSkipSeekCoalesceUntil = DateTime.now().add(
      _kWebSkipSeekAfterLiveReload,
    );
    _webForceBufferLiveEdgeOnPlaying = true;
    try {
      await _webPlayWithAutoplayPolicy(el);
      await _webAwaitPlayActuallyStarted(el);
      _webUpdateLiveEdgeFromBufferPosition(el);
      _syncWebMediaSessionPlaybackState(el);
    } catch (_) {
      _webForceBufferLiveEdgeOnPlaying = false;
      bibleFmWebLiveEdgeActive.value = false;
      _syncWebPlaybackNotifierFrom(el);
      _syncWebMediaSessionPlaybackState(el);
    }
  } finally {
    await _webEnsureMinLiveSpinnerShown(spinnerStarted);
    bibleFmWebLiveReloading.value = false;
  }
}

/// Controlo nativo do browser (`<audio controls>` — p.ex. barra do Chrome).
class WebNativeAudioControls extends StatefulWidget {
  const WebNativeAudioControls({
    super.key,
    required this.streamUrl,
    this.controlsHeight = 44,
  });

  final String streamUrl;
  final double controlsHeight;

  @override
  State<WebNativeAudioControls> createState() => _WebNativeAudioControlsState();
}

class _WebNativeAudioControlsState extends State<WebNativeAudioControls> {
  static const String _viewType = 'bibliofani-chrome-audio';
  static bool _factoryRegistered = false;

  void _syncNativeControlsColorScheme() {
    final wrap = _webAudioControlsWrap;
    if (wrap == null || !mounted) return;
    // Sempre escuro: glifos do Chromium claros (branco) sobre painel transparente/independente do tema da app.
    const scheme = 'dark';
    wrap.style.setProperty('color-scheme', scheme);
    wrap.style.setProperty('background', 'transparent');
    wrap.style.setProperty('box-shadow', 'none');
    final a = _webBibleFmAudio;
    if (a != null) {
      a.style.setProperty('background-color', 'transparent');
      a.style.setProperty('color-scheme', scheme);
      a.style.setProperty('accent-color', '#ffffff');
      a.style.setProperty('color', '#ffffff');
    }
  }

  @override
  void initState() {
    super.initState();
    _registerFactoryOnce();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNativeControlsColorScheme();
    });
  }

  @override
  void didUpdateWidget(WebNativeAudioControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNativeControlsColorScheme();
    });
  }

  void _registerFactoryOnce() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;
    final url = widget.streamUrl;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      _ensureAudioControlsChromeCss();
      // metadata: negocia sessão / metadados cedo sem descarregar o fluxo inteiro — primeiro play em geral mais rápido que none.
      final a = html.AudioElement()
        ..controls = true
        ..preload = 'metadata'
        ..src = url
        ..title = 'Bibliofani'
        ..className = 'bibliofani-native-audio'
        ..setAttribute('aria-label', kBibleFmWebFrNativeAudioAriaLabel)
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.maxHeight = '100%'
        ..style.display = 'block'
        ..style.setProperty('background-color', 'transparent');
      final wrap = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.boxSizing = 'border-box'
        ..style.overflow = 'hidden'
        ..style.borderRadius = '14px'
        ..style.setProperty('color-scheme', 'dark')
        ..style.setProperty('background', 'transparent')
        ..style.setProperty('box-shadow', 'none')
        ..append(a);
      _webAudioControlsWrap = wrap;
      _installWheelRelayOnAudioWrap(wrap);
      _webBibleFmAudio = a;
      _webLiveStreamBaseUrl = url;
      a.onPlay.listen((_) => _onWebAudioPlay(a));
      a.onPause.listen((_) => _onWebAudioPauseOrEnd(a));
      a.onEnded.listen((_) => _onWebAudioPauseOrEnd(a));
      a.onWaiting.listen((_) {
        bibleFmWebBuffering.value = true;
      });
      a.onStalled.listen((_) {
        bibleFmWebBuffering.value = true;
      });
      a.onCanPlay.listen((_) {
        bibleFmWebBuffering.value = false;
      });
      a.onPlaying.listen((_) {
        bibleFmWebBuffering.value = false;
        if (_webForceBufferLiveEdgeOnPlaying) {
          _webUpdateLiveEdgeFromBufferPosition(a);
        } else if (_webPreferListenModeAfterPause) {
          bibleFmWebLiveEdgeActive.value = false;
        } else {
          _webUpdateLiveEdgeFromBufferPosition(a);
        }
      });
      void onProgressClamp(html.Event _) {
        final el = _webBibleFmAudio;
        if (el == null || el.paused || el.seeking) return;
        _webClampPlayingCurrentTimeToLiveCeiling(el);
      }

      a.addEventListener('progress', onProgressClamp);
      a.onTimeUpdate.listen((_) {
        final el = _webBibleFmAudio;
        if (el == null || el.seeking) return;
        if (!el.paused) {
          _webClampPlayingCurrentTimeToLiveCeiling(el);
        }
        final clampTo = _webScrubClampTargetSec(el);
        if (clampTo != null) {
          _webResyncSessionClockToSeconds(clampTo, paused: el.paused);
          _webProgrammaticTimelineSeekPending++;
          try {
            el.currentTime = clampTo;
          } catch (_) {
            _webProgrammaticTimelineSeekPending--;
          }
          _webUpdateLiveEdgeFromBufferPosition(el);
        }
      });
      a.onSeeked.listen((_) => _onWebAudioSeeked(a));
      a.onError.listen((_) {
        _webCancelLiveCeilingRapidGuard();
        bibleFmWebBuffering.value = false;
        bibleFmWebLiveEdgeActive.value = false;
        _syncWebPlaybackNotifierFrom(a);
        _syncWebMediaSessionPlaybackState(a);
      });
      a.onLoadedData.listen((_) => _syncNativeAudioElapsedDisplay());
      a.onLoadedMetadata.listen((_) => _syncNativeAudioElapsedDisplay());
      _syncNativeAudioElapsedDisplay();
      _initWebAudioNotifiersAndMediaSession(a);
      return wrap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 520.0;
        final h = widget.controlsHeight;
        return Semantics(
          container: true,
          label: kBibleFmWebFrNativeAudioSemanticsLabel,
          hint: kBibleFmWebFrNativeAudioSemanticsHint,
          child: SizedBox(
            width: w,
            height: h,
            child: const HtmlElementView(viewType: _viewType),
          ),
        );
      },
    );
  }
}
