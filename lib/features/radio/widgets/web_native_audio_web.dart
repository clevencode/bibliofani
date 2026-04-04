// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:bibleco/core/strings/bible_fm_strings.dart';

const _kWebCanPlayTimeout = Duration(seconds: 10);
const _kWebPlayStartTimeout = Duration(seconds: 12);
const _kWebLiveSpinnerMin = Duration(milliseconds: 280);
const _kWebSkipSeekAfterLiveReload = Duration(seconds: 4);
const _kWebStaleResumeReconnectAfter = Duration(minutes: 30);
const double _kWebLiveEdgeBufferMarginSec = 2.5;
const double _kWebScrubLiveCeilingEpsilonSec = 0.12;
const double _kWebLiveCeilingOverrunSnapSec = 1e-5;
const Duration _kWebLiveCeilingGuardInterval = Duration(milliseconds: 16);
const double _kWebLogicalBufferWindowSec = 10.0;

html.AudioElement? _webBibleFmAudio;

bool _webMediaSessionAppListenersAttached = false;

html.DivElement? _webAudioControlsWrap;

String? _webLiveStreamBaseUrl;

const _kAudioChromeStyleId = 'bibleco-audio-chrome-style-v1';
const _kLiveDurationHookScriptId = 'bibleco-duration-hook-script-v1';

void _ensureLiveDurationHookScript() {
  if (html.document.getElementById(_kLiveDurationHookScriptId) != null) {
    return;
  }
  final script = html.ScriptElement()
    ..id = _kLiveDurationHookScriptId
    ..type = 'text/javascript'
    ..text = r'''
(function(w) {
  var HOOK_VER = 4;
  if (w.__bfmLiveDurHookVer === HOOK_VER) return;
  if (w.__bfmLiveDurTimer) {
    clearInterval(w.__bfmLiveDurTimer);
    w.__bfmLiveDurTimer = null;
  }
  w.__bfmLiveDurHookVer = HOOK_VER;
  try {
    var oldA = document.querySelector('.bibleco-native-audio');
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
    var a = document.querySelector('.bibleco-native-audio');
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
.bibleco-native-audio {
  background-color: transparent !important;
  color-scheme: dark !important;
  accent-color: #ffffff !important;
  color: #ffffff !important;
}
.bibleco-native-audio::-webkit-media-controls-panel,
.bibleco-native-audio::-webkit-media-controls-enclosure {
  background-color: rgba(0, 0, 0, 0) !important;
}
.bibleco-native-audio::-webkit-media-controls-current-time-display,
.bibleco-native-audio::-webkit-media-controls-time-remaining-display {
  color: #ffffff !important;
  text-shadow: none !important;
}
''';
  html.document.head?.append(style);
  _ensureLiveDurationHookScript();
}

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

void _installWebMediaSession(html.AudioElement a) {
  final ms = html.window.navigator.mediaSession;
  if (ms == null) return;

  void safePlay() => unawaited(a.play().catchError((Object? _) {}));

  void safePause() {
    try {
      a.pause();
    } catch (_) {}
  }

  try {
    ms.setActionHandler('play', () => safePlay());
    ms.setActionHandler('pause', safePause);
    ms.setActionHandler('seekbackward', () {
      if (!bibleFmWebLiveReloading.value && bibleFmWebSessionEverStarted.value) {
        bibleFmWebSeekRelativeSeconds(-10);
      }
    });
    ms.setActionHandler('seekforward', () {
      if (!bibleFmWebLiveReloading.value && bibleFmWebSessionEverStarted.value) {
        bibleFmWebSeekRelativeSeconds(10);
      }
    });
  } catch (_) {}
}

String _webMediaSessionArtistLineFr() {
  final reloading = bibleFmWebLiveReloading.value;
  final playing = bibleFmWebPlaybackActive.value;
  final buffering = bibleFmWebBuffering.value;
  final liveEdge = bibleFmWebLiveEdgeActive.value;
  final sessionStarted = bibleFmWebSessionEverStarted.value;
  if (reloading) return kBibleFmWebFrFeedbackReloading;
  if (playing && buffering) return kBibleFmWebFrFeedbackBuffering;
  if (playing && liveEdge) return kBibleFmWebFrFeedbackLive;
  if (playing) return kBibleFmWebFrFeedbackListening;
  if (sessionStarted) return kBibleFmWebFrFeedbackPaused;
  return kBibleFmWebFrFeedbackReady;
}

String _webMediaSessionPlaybackStateStr() {
  if (bibleFmWebLiveReloading.value) return 'none';
  if (!bibleFmWebSessionEverStarted.value) return 'none';
  final a = _webBibleFmAudio;
  if (a != null && a.paused) return 'paused';
  return 'playing';
}

void _syncWebMediaSessionFromApp() {
  final ms = html.window.navigator.mediaSession;
  if (ms == null) return;
  try {
    ms.metadata = html.MediaMetadata({
      'title': kBibleFmMediaSessionTitle,
      'artist': _webMediaSessionArtistLineFr(),
      'album': kBibleFmMediaSessionAlbum,
    });
    ms.playbackState = _webMediaSessionPlaybackStateStr();
  } catch (_) {}
}

void _webMediaSessionAppSyncTick() {
  _syncWebMediaSessionFromApp();
}

void _initWebAudioNotifiersAndMediaSession(html.AudioElement a) {
  _installWebMediaSession(a);
  if (!_webMediaSessionAppListenersAttached) {
    _webMediaSessionAppListenersAttached = true;
    bibleFmWebBuffering.addListener(_webMediaSessionAppSyncTick);
    bibleFmWebLiveReloading.addListener(_webMediaSessionAppSyncTick);
    bibleFmWebLiveEdgeActive.addListener(_webMediaSessionAppSyncTick);
    bibleFmWebSessionEverStarted.addListener(_webMediaSessionAppSyncTick);
    bibleFmWebPlaybackActive.addListener(_webMediaSessionAppSyncTick);
  }
  _syncWebPlaybackNotifierFrom(a);
}

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

void bibleFmWebPausePlayback() {
  final el = _webBibleFmAudio;
  if (el == null) return;
  try {
    el.pause();
  } catch (_) {}
}

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

final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);
final bibleFmWebLiveReloading = ValueNotifier<bool>(false);
final bibleFmWebLiveEdgeActive = ValueNotifier<bool>(false);
final bibleFmWebBuffering = ValueNotifier<bool>(false);
final bibleFmWebSessionEverStarted = ValueNotifier<bool>(false);
final bibleFmWebLiveMovedWhilePausedSec = ValueNotifier<double?>(null);

double? _webBufferedEndAtPauseFromLive;

Timer? _webPauseLiveDriftTimer;

Timer? _webLiveCeilingRapidGuardTimer;

DateTime? _webPlayingSince;
Duration _webElapsedPriorSegments = Duration.zero;

DateTime? _webPausedSince;
Timer? _webSessionTickTimer;

DateTime? _webSkipSeekCoalesceUntil;

int _webProgrammaticTimelineSeekPending = 0;

bool _webPreferListenModeAfterPause = false;

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

double? _logicalBufferedStartSec(html.AudioElement a) {
  final end = _bufferedEndSec(a);
  final start = _bufferedStartSec(a);
  if (end == null || start == null) return null;
  if (!end.isFinite || !start.isFinite) return null;
  final span = end - start;
  if (span <= _kWebLogicalBufferWindowSec) return start;
  return end - _kWebLogicalBufferWindowSec;
}

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

void _webResyncSessionClockToAudioPosition(html.AudioElement a) {
  _webResyncSessionClockToSeconds(a.currentTime.toDouble(), paused: a.paused);
}

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

    _webClampPlayingCurrentTimeToLiveCeiling(a);

    if (_webSkipSeekCoalesceUntil != null &&
        DateTime.now().isBefore(_webSkipSeekCoalesceUntil!)) {
      return;
    }

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
    final tightDriftCap =
        bibleFmWebLiveEdgeActive.value ? 0.12 : 1.15;
    if (drift <= tightDriftCap) return;
    _webAssignCurrentTimeForSync(a, target);
  } catch (_) {}
}

void _syncWebPlaybackNotifierFrom(html.AudioElement a) {
  bibleFmWebPlaybackActive.value = !a.paused;
  _syncWebMediaSessionFromApp();
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
  bibleFmWebBuffering.value =
      a.readyState < html.MediaElement.HAVE_CURRENT_DATA;
  _webPlayingSince ??= DateTime.now();
  _webPausedSince = null;
  _syncWebPlaybackNotifierFrom(a);
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

Future<void> _webAwaitPlayActuallyStarted(html.AudioElement el) async {
  if (!el.paused && el.readyState >= html.MediaElement.HAVE_CURRENT_DATA) {
    return;
  }
  try {
    await el.onPlay.first.timeout(_kWebPlayStartTimeout);
  } on TimeoutException catch (_) {
    return;
  }
}

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
    } catch (_) {
      _webForceBufferLiveEdgeOnPlaying = false;
      bibleFmWebLiveEdgeActive.value = false;
      _syncWebPlaybackNotifierFrom(el);
    }
  } finally {
    await _webEnsureMinLiveSpinnerShown(spinnerStarted);
    bibleFmWebLiveReloading.value = false;
  }
}

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
  static const String _viewType = 'bibleco-chrome-audio';
  static bool _factoryRegistered = false;

  void _syncNativeControlsColorScheme() {
    final wrap = _webAudioControlsWrap;
    if (wrap == null || !mounted) return;
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
      final a = html.AudioElement()
        ..controls = true
        ..preload = 'metadata'
        ..src = url
        ..title = 'bibleco'
        ..className = 'bibleco-native-audio'
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
        final el = _webBibleFmAudio;
        if (el != null && !el.paused && !el.seeking) {
          _webClampPlayingCurrentTimeToLiveCeiling(el);
        }
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
        if (!a.paused && !a.seeking) {
          _webClampPlayingCurrentTimeToLiveCeiling(a);
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
