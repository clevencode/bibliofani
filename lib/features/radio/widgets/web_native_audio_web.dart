// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

html.AudioElement? _webBibleFmAudio;

/// Subscrição única: primeiro gesto após falha de autoplay (política do browser).
StreamSubscription? _webAutoplayUnlockSub;

void _cancelWebAutoplayUnlock() {
  _webAutoplayUnlockSub?.cancel();
  _webAutoplayUnlockSub = null;
}

/// [Media Session](https://w3c.github.io/mediasession/): centro de média do SO, teclas físicas, notificação.
void _installWebMediaSession(html.AudioElement a) {
  final ms = html.window.navigator.mediaSession;
  if (ms == null) return;
  try {
    ms.metadata = html.MediaMetadata({
      'title': 'Bible FM',
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

/// Autoplay com [HTMLMediaElement.play](https://html.spec.whatwg.org/#dom-media-play);
/// se falhar (NotAllowedError), o primeiro [pointerdown] ou [click] desbloqueia — padrão recomendado.
Future<void> _bootstrapWebPlayback(html.AudioElement a) async {
  _installWebMediaSession(a);
  _syncWebMediaSessionPlaybackState(a);

  late StreamSubscription<html.Event> firstPlaySub;
  firstPlaySub = a.onPlay.listen((_) {
    firstPlaySub.cancel();
    _cancelWebAutoplayUnlock();
  });

  // Deixa o platform view estabelecer o nó no DOM antes do primeiro play().
  await Future<void>.microtask(() {});

  try {
    await a.play();
    return;
  } catch (_) {
    _cancelWebAutoplayUnlock();
    void unlock(html.Event event) {
      _cancelWebAutoplayUnlock();
      unawaited(a.play().catchError((Object? error) {}));
    }

    // `click` e `keydown` são gestos válidos para desbloquear autoplay; `pointerdown`
    // não está exposto em todos os alvos em dart:html — usar janela.
    _webAutoplayUnlockSub = html.window.onClick.listen(unlock);
  }
}

/// `true` enquanto o `<audio>` está a reproduzir (para opacidade do botão «live» na web).
final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);

/// `true` durante [bibleFmWebReloadLiveStream] — spinner no botão live (padrão TuneIn).
final bibleFmWebLiveReloading = ValueNotifier<bool>(false);

/// Depois de religar ao fluxo com sucesso: sincronizado com «já em directo» (desactiva live até pausa).
final bibleFmWebLiveEdgeActive = ValueNotifier<bool>(false);

/// `waiting` no `<audio>` (feedback no título).
final bibleFmWebBuffering = ValueNotifier<bool>(false);

/// `true` após o primeiro play (distigue pausa de «ainda não iniciou»).
final bibleFmWebSessionEverStarted = ValueNotifier<bool>(false);

DateTime? _webPlayingSince;
Duration _webElapsedPriorSegments = Duration.zero;

/// Início da pausa actual (relógio de parede) — salto TuneIn ao tocar em live.
DateTime? _webPausedSince;
Timer? _webSessionTickTimer;

/// Após [src] novo + [play], evita «seek» para o tempo de sessão (>> buffer) que **parava** o áudio no Chrome.
DateTime? _webSkipSeekCoalesceUntil;

double? _bufferedEndSec(html.AudioElement a) {
  final b = a.buffered;
  if (b.length == 0) return null;
  return b.end(b.length - 1);
}

/// Limite seguro: nunca pedir `currentTime` acima do que o buffer expõe (streams ao vivo).
double _safeTargetCurrentTimeSec(html.AudioElement a, double sessionSec) {
  final end = _bufferedEndSec(a);
  if (end == null) return sessionSec;
  return sessionSec <= end ? sessionSec : end;
}

/// Expõe o tempo de sessão no **próprio** `currentTime` do `<audio controls>` (reutilização; sem segundo contador).
void _syncNativeAudioElapsedDisplay() {
  final a = _webBibleFmAudio;
  if (a == null) return;
  final sessionSec = _webSessionTotalElapsed().inMicroseconds / 1e6;
  if (!sessionSec.isFinite || sessionSec < 0) return;

  if (a.paused) {
    try {
      final end = _bufferedEndSec(a);
      if (end == null && sessionSec > 1.5) {
        return;
      }
      final target = _safeTargetCurrentTimeSec(a, sessionSec);
      if ((a.currentTime - target).abs() > 0.04) {
        a.currentTime = target;
      }
    } catch (_) {}
    return;
  }

  if (_webSkipSeekCoalesceUntil != null &&
      DateTime.now().isBefore(_webSkipSeekCoalesceUntil!)) {
    return;
  }

  final end = _bufferedEndSec(a);
  if (end != null && sessionSec > end + 0.05) {
    return;
  }

  final target = _safeTargetCurrentTimeSec(a, sessionSec);
  final drift = (target - a.currentTime).abs();
  if (drift <= 1.15) return;
  try {
    a.currentTime = target;
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
  _webSessionTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    _syncNativeAudioElapsedDisplay();
  });
}

void _webStopSessionTick() {
  _webSessionTickTimer?.cancel();
  _webSessionTickTimer = null;
  _syncNativeAudioElapsedDisplay();
}

void _onWebAudioPlay(html.AudioElement a) {
  bibleFmWebSessionEverStarted.value = true;
  bibleFmWebBuffering.value = false;
  _webPlayingSince ??= DateTime.now();
  _webPausedSince = null;
  _syncWebPlaybackNotifierFrom(a);
  _syncWebMediaSessionPlaybackState(a);
  _webStartSessionTick();
  _syncNativeAudioElapsedDisplay();
}

void _onWebAudioPauseOrEnd(html.AudioElement a) {
  bibleFmWebBuffering.value = false;
  bibleFmWebLiveEdgeActive.value = false;
  _webFoldPlayingSegment();
  _webPausedSince = DateTime.now();
  _webStopSessionTick();
  _syncWebPlaybackNotifierFrom(a);
  _syncWebMediaSessionPlaybackState(a);
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
  const minShow = Duration(milliseconds: 280);
  final elapsed = DateTime.now().difference(started);
  if (elapsed < minShow) {
    await Future<void>.delayed(minShow - elapsed);
  }
}

/// Garante que o spinner cobre buffer + primeiro frame de áudio (TuneIn), não só a Promise do [play].
Future<void> _webAwaitPlayActuallyStarted(html.AudioElement el) async {
  if (!el.paused &&
      el.readyState >= html.MediaElement.HAVE_CURRENT_DATA) {
    return;
  }
  try {
    await el.onPlay.first.timeout(const Duration(seconds: 12));
  } on TimeoutException {
    // Mantém coerência com o finally (spinner + edge).
  }
}

/// Religa o fluxo ao instante actual e **inicia reprodução** (toque no live = gesto).
Future<void> bibleFmWebReloadLiveStream(String baseUrl) async {
  final el = _webBibleFmAudio;
  if (el == null) return;
  if (bibleFmWebLiveReloading.value) return;
  final spinnerStarted = DateTime.now();
  bibleFmWebLiveReloading.value = true;
  try {
    _webApplyLiveElapsedJumpFromPausedWallClock();
    var uri = Uri.parse(baseUrl);
    final q = Map<String, String>.from(uri.queryParameters);
    q['_'] = DateTime.now().millisecondsSinceEpoch.toString();
    uri = uri.replace(queryParameters: q);
    el.src = uri.toString();
    el.load();
    _webSkipSeekCoalesceUntil = DateTime.now().add(const Duration(seconds: 4));
    try {
      await el.play();
      await _webAwaitPlayActuallyStarted(el);
      bibleFmWebLiveEdgeActive.value = !el.paused;
      _syncWebMediaSessionPlaybackState(el);
    } catch (_) {
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
  static const String _viewType = 'bible-fm-chrome-audio';
  static bool _factoryRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerFactoryOnce();
  }

  void _registerFactoryOnce() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;
    final url = widget.streamUrl;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      // preload=none: boa prática para streams contínuos até haver play() (poupa dados).
      final a = html.AudioElement()
        ..controls = true
        ..preload = 'none'
        ..src = url
        ..title = 'Bible FM'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.maxHeight = '100%'
        ..style.display = 'block';
      final wrap = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.boxSizing = 'border-box'
        ..append(a);
      _webBibleFmAudio = a;
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
      });
      a.onError.listen((_) {
        bibleFmWebBuffering.value = false;
        _syncWebPlaybackNotifierFrom(a);
        _syncWebMediaSessionPlaybackState(a);
      });
      a.onLoadedData.listen((_) => _syncNativeAudioElapsedDisplay());
      a.onLoadedMetadata.listen((_) => _syncNativeAudioElapsedDisplay());
      _syncWebPlaybackNotifierFrom(a);
      _syncNativeAudioElapsedDisplay();
      unawaited(_bootstrapWebPlayback(a));
      return wrap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 520.0;
        final h = widget.controlsHeight;
        return SizedBox(
          width: w,
          height: h,
          child: const HtmlElementView(viewType: _viewType),
        );
      },
    );
  }
}
