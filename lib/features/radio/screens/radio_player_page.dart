import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';
import 'package:meu_app/features/radio/widgets/web_native_audio.dart';

/// Ancora visual: barra do temporizador alinha logo abaixo desta cápsula.
final GlobalKey _kWebTransportCapsule = GlobalKey(
  debugLabel: 'webTransportCapsule',
);

/// Referência ao botão de sleep para acionar o mesmo fluxo do clique.
final GlobalKey<_WebSleepTimerButtonState> _kWebSleepTimerButtonKey =
    GlobalKey<_WebSleepTimerButtonState>(debugLabel: 'webSleepTimerButton');

/// Métricas da barra de transporte: breakpoints, escala de texto e espaçamentos.
@immutable
class _WebTransportLayoutSpec {
  const _WebTransportLayoutSpec({
    required this.maxContentWidth,
    required this.hPadLeft,
    required this.hPadRight,
    required this.vPad,
    required this.feedbackBelowGap,
    required this.capsuleHeight,
    required this.padH,
    required this.padV,
    required this.liveDiameter,
    required this.audioControlsHeight,
    required this.gapLiveAudio,
    required this.gapAudioSleep,
    required this.showDesktopScrollbars,
    required this.feedbackUseSmallerType,
  });

  final double maxContentWidth;
  final double hPadLeft;
  final double hPadRight;
  final double vPad;
  final double feedbackBelowGap;
  final double capsuleHeight;
  final double padH;
  final double padV;
  final double liveDiameter;
  final double audioControlsHeight;
  final double gapLiveAudio;
  final double gapAudioSleep;
  final bool showDesktopScrollbars;
  final bool feedbackUseSmallerType;

  double get innerHeight => capsuleHeight - 2 * padV;

  static _WebTransportLayoutSpec compute({
    required double layoutW,
    required double layoutH,
    required TextScaler textScaler,
  }) {
    final tScale = textScaler.scale(1.0);
    final cappedScale = tScale.clamp(1.0, 1.45);
    final gentleScale = math.pow(cappedScale, 0.38).toDouble();

    final narrow = layoutW < 360;
    final compact = layoutW < 440;
    final medium = layoutW < 720;
    final wide = layoutW >= 900;

    final baseH = narrow ? 10.0 : (compact ? 12.0 : (medium ? 18.0 : 24.0));
    final hPadLeft = baseH;
    final hPadRight = baseH;
    final availableW = math.max(0.0, layoutW - hPadLeft - hPadRight);
    final maxContent = wide
        ? math.min(720.0, availableW)
        : (layoutW >= 600
              ? math.min(640.0, availableW)
              : math.min(560.0, availableW));

    final shortViewport = layoutH > 0 && layoutH < 520;
    final feedbackBelowGap = shortViewport ? 10.0 : (compact ? 12.0 : 16.0);

    final padH = narrow ? 5.0 : (compact ? 6.0 : 8.0);
    final padV = narrow ? 5.0 : (compact ? 6.0 : 5.0);

    final liveBase = compact ? 48.0 : 46.0;
    final liveDiameter = (liveBase * cappedScale.clamp(1.0, 1.12)).clamp(
      44.0,
      56.0,
    );

    final audioBase = compact ? 48.0 : 42.0;
    final audioControlsHeight = (audioBase * cappedScale.clamp(1.0, 1.18))
        .clamp(40.0, 56.0);

    final capsuleBase = compact ? 56.0 : 54.0;
    final innerNeeded = math.max(liveDiameter, audioControlsHeight) + 2.0;
    final capsuleHeight = math
        .max(
          (capsuleBase * gentleScale).clamp(50.0, 68.0),
          innerNeeded + 2 * padV,
        )
        .clamp(50.0, 76.0);

    final gapLiveAudio = narrow ? 8.0 : 10.0;
    final gapAudioSleep = narrow ? 6.0 : 8.0;

    final vPad = compact ? 6.0 : (shortViewport ? 4.0 : 10.0);

    return _WebTransportLayoutSpec(
      maxContentWidth: maxContent > 0 ? maxContent : availableW,
      hPadLeft: hPadLeft,
      hPadRight: hPadRight,
      vPad: vPad,
      feedbackBelowGap: feedbackBelowGap,
      capsuleHeight: capsuleHeight,
      padH: padH,
      padV: padV,
      liveDiameter: liveDiameter,
      audioControlsHeight: audioControlsHeight,
      gapLiveAudio: gapLiveAudio,
      gapAudioSleep: gapAudioSleep,
      showDesktopScrollbars: !compact && layoutW >= 520,
      feedbackUseSmallerType: layoutW < 380 || cappedScale > 1.15,
    );
  }
}

/// BibloPhani — leitor **apenas Web** (`<audio controls>` + botão directo).
class RadioPlayerPage extends StatelessWidget {
  const RadioPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: kBibleFmSemanticsPlayerPage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: kBibleFmWebFrBackgroundGestureA11y,
              onTap: bibleFmWebBackgroundTapPlayPause,
              onLongPress: bibleFmWebBackgroundLongPressGoLive,
              child: Material(
                type: MaterialType.transparency,
                child: Ink(
                  decoration: BoxDecoration(
                    color: brightness == Brightness.dark
                        ? scheme.surface
                        : null,
                    gradient: brightness == Brightness.dark
                        ? null
                        : AppTheme.notionLightBackgroundGradient,
                  ),
                  child: InkWell(
                    onTap: bibleFmWebBackgroundTapPlayPause,
                    onLongPress: bibleFmWebBackgroundLongPressGoLive,
                    splashFactory:
                        InkSparkle.constantTurbulenceSeedSplashFactory,
                    // Efeito granulado sem véu de cor opaco: só faíscas sobre o fundo.
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    // Sem véu de cor ao pairar: o fundo visual permanece idêntico.
                    hoverColor: Colors.transparent,
                    mouseCursor: SystemMouseCursors.click,
                    canRequestFocus: false,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            SafeArea(child: _WebPlayerScrollBridge(brightness: brightness)),
          ],
        ),
      ),
    );
  }
}

/// Scroll duplo + registo dos controladores para a roda sobre o `<audio>` (Web).
class _WebPlayerScrollBridge extends StatefulWidget {
  const _WebPlayerScrollBridge({required this.brightness});

  final Brightness brightness;

  @override
  State<_WebPlayerScrollBridge> createState() => _WebPlayerScrollBridgeState();
}

class _WebPlayerScrollBridgeState extends State<_WebPlayerScrollBridge> {
  late final ScrollController _verticalScroll = ScrollController();
  late final ScrollController _horizontalScroll = ScrollController();
  final GlobalKey _measureKey = GlobalKey(debugLabel: 'webPlayerMeasure');

  /// Uma única leitura de layout por frame (evita vários postFrameCallbacks / reflows em cascata).
  bool _overflowFrameScheduled = false;
  BoxConstraints? _overflowConstraintsQueued;
  bool _useScrollLayout = false;

  @override
  void initState() {
    super.initState();
    bibleFmWebAttachScrollBridge(_verticalScroll, _horizontalScroll);
    _verticalScroll.addListener(_onScrollControllersChanged);
    _horizontalScroll.addListener(_onScrollControllersChanged);
  }

  @override
  void dispose() {
    _verticalScroll.removeListener(_onScrollControllersChanged);
    _horizontalScroll.removeListener(_onScrollControllersChanged);
    bibleFmWebDetachScrollBridge();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _onScrollControllersChanged() {
    if (!_useScrollLayout || !mounted) return;
    if (!_verticalScroll.hasClients || !_horizontalScroll.hasClients) return;
    final v = _verticalScroll.position.maxScrollExtent;
    final h = _horizontalScroll.position.maxScrollExtent;
    if (v <= 0.5 && h <= 0.5) {
      setState(() {
        _useScrollLayout = false;
        _overflowConstraintsQueued = null;
      });
    }
  }

  void _onLayoutTick(BoxConstraints constraints) {
    if (!mounted || _useScrollLayout) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final needsVertical = box.size.height > constraints.maxHeight + 0.5;
    final needsHorizontal = box.size.width > constraints.maxWidth + 0.5;
    if (needsVertical || needsHorizontal) {
      setState(() {
        _useScrollLayout = true;
        _overflowConstraintsQueued = null;
      });
    }
  }

  void _scheduleOverflowCheck(BoxConstraints constraints) {
    _overflowConstraintsQueued = constraints;
    if (_overflowFrameScheduled) return;
    _overflowFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overflowFrameScheduled = false;
      final queued = _overflowConstraintsQueued;
      _overflowConstraintsQueued = null;
      if (!mounted || queued == null) return;
      _onLayoutTick(queued);
    });
  }

  Widget _transportColumn({
    required Brightness brightness,
    required _WebTransportLayoutSpec spec,
  }) {
    final innerH = spec.innerHeight;
    return Column(
      key: _measureKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WebRealtimeFeedbackLine(useSmallerType: spec.feedbackUseSmallerType),
        SizedBox(height: spec.feedbackBelowGap),
        DecoratedBox(
          key: _kWebTransportCapsule,
          decoration: AppTheme.transportCapsuleDecoration(
            brightness: brightness,
            radius: spec.capsuleHeight / 2,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spec.padH,
              spec.padV,
              spec.padH,
              spec.padV,
            ),
            child: SizedBox(
              height: innerH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _WebLiveStreamButton(diameter: spec.liveDiameter),
                  SizedBox(width: spec.gapLiveAudio),
                  Expanded(
                    child: WebNativeAudioControls(
                      streamUrl: kBibleFmLiveStreamUrl,
                      controlsHeight: spec.audioControlsHeight,
                    ),
                  ),
                  SizedBox(width: spec.gapAudioSleep),
                  _WebSleepTimerButton(
                    key: _kWebSleepTimerButtonKey,
                    controlHeight: innerH,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sleepSwipeWrapper({
    required Widget child,
    required bool compactLayout,
  }) {
    final swipeVy = compactLayout ? 130.0 : 180.0;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final vy = details.velocity.pixelsPerSecond.dy;
        if (vy > swipeVy) {
          _kWebSleepTimerButtonKey.currentState?.openFromScreenSwipe();
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness;

    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleOverflowCheck(constraints);

        final layoutW = constraints.maxWidth;
        final layoutH = constraints.maxHeight;
        final textScaler = MediaQuery.textScalerOf(context);
        final spec = _WebTransportLayoutSpec.compute(
          layoutW: layoutW,
          layoutH: layoutH.isFinite ? layoutH : 0,
          textScaler: textScaler,
        );
        final compact = layoutW < 440;

        final column = _transportColumn(brightness: brightness, spec: spec);

        final paddedColumn = Padding(
          padding: EdgeInsets.fromLTRB(
            spec.hPadLeft,
            spec.vPad,
            spec.hPadRight,
            spec.vPad,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spec.maxContentWidth),
            child: column,
          ),
        );

        final showScrollbars = spec.showDesktopScrollbars;

        if (!_useScrollLayout) {
          return _sleepSwipeWrapper(
            compactLayout: compact,
            child: Center(child: paddedColumn),
          );
        }

        return Scrollbar(
          thumbVisibility: showScrollbars,
          notificationPredicate: (ScrollNotification n) =>
              n.metrics.axis == Axis.vertical,
          controller: _verticalScroll,
          child: SingleChildScrollView(
            controller: _verticalScroll,
            scrollDirection: Axis.vertical,
            physics: const ClampingScrollPhysics(),
            child: Scrollbar(
              thumbVisibility: showScrollbars,
              notificationPredicate: (ScrollNotification n) =>
                  n.metrics.axis == Axis.horizontal,
              controller: _horizontalScroll,
              child: SingleChildScrollView(
                controller: _horizontalScroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: bibleFmWebBackgroundTapPlayPause,
                          onLongPress: bibleFmWebBackgroundLongPressGoLive,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      _sleepSwipeWrapper(
                        compactLayout: compact,
                        child: paddedColumn,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _webPlaybackFeedbackMessage({
  required bool reloading,
  required bool playing,
  required bool buffering,
  required bool liveEdge,
  required bool sessionStarted,
}) {
  if (reloading) return kBibleFmWebFrFeedbackReloading;
  if (playing && buffering) return kBibleFmWebFrFeedbackBuffering;
  if (playing && liveEdge) return kBibleFmWebFrFeedbackLive;
  if (playing) return kBibleFmWebFrFeedbackListening;
  if (sessionStarted) return kBibleFmWebFrFeedbackPaused;
  return kBibleFmWebFrFeedbackReady;
}

Color _webPlaybackFeedbackColor(
  BuildContext context, {
  required bool playing,
  required bool liveEdge,
  required bool reloading,
  required bool buffering,
  required bool sessionStarted,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (playing && liveEdge) {
    return scheme.primary;
  }
  if (reloading || (playing && buffering)) {
    return scheme.onSurfaceVariant;
  }
  if (playing) return scheme.onSurface;
  if (sessionStarted) {
    return scheme.onSurface.withValues(alpha: 0.88);
  }
  return scheme.onSurfaceVariant;
}

class _WebRealtimeFeedbackLine extends StatelessWidget {
  const _WebRealtimeFeedbackLine({required this.useSmallerType});

  final bool useSmallerType;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        bibleFmWebPlaybackActive,
        bibleFmWebLiveReloading,
        bibleFmWebLiveEdgeActive,
        bibleFmWebBuffering,
        bibleFmWebSessionEverStarted,
      ]),
      builder: (context, _) {
        final playing = bibleFmWebPlaybackActive.value;
        final reloading = bibleFmWebLiveReloading.value;
        final liveEdge = bibleFmWebLiveEdgeActive.value;
        final buffering = bibleFmWebBuffering.value;
        final sessionStarted = bibleFmWebSessionEverStarted.value;
        final msg = _webPlaybackFeedbackMessage(
          reloading: reloading,
          playing: playing,
          buffering: buffering,
          liveEdge: liveEdge,
          sessionStarted: sessionStarted,
        );
        final color = _webPlaybackFeedbackColor(
          context,
          playing: playing,
          liveEdge: liveEdge,
          reloading: reloading,
          buffering: buffering,
          sessionStarted: sessionStarted,
        );
        final showOnAirDot = playing && liveEdge && !reloading;
        final onAirColor = Theme.of(context).colorScheme.error;
        final theme = Theme.of(context);
        final TextStyle? feedbackStyle =
            (useSmallerType
                    ? theme.textTheme.bodySmall
                    : theme.textTheme.bodyMedium)
                ?.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                  letterSpacing: 0.12,
                );

        final dotReserve = showOnAirDot ? 14.0 : 0.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final textMaxW = math.max(0.0, constraints.maxWidth - dotReserve);
            return Semantics(
              liveRegion: true,
              label: msg,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showOnAirDot) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: onAirColor,
                          boxShadow: [
                            BoxShadow(
                              color: onAirColor.withValues(alpha: 0.28),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textMaxW),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) {
                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [...previous, ?current],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          final pull =
                              Tween<Offset>(
                                begin: const Offset(0, 0.22),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );
                          return SlideTransition(
                            position: pull,
                            child:
                                FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: Text(
                          msg,
                          key: ValueKey<String>(msg),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: feedbackStyle?.copyWith(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WebLiveStreamButton extends StatelessWidget {
  const _WebLiveStreamButton({this.diameter = 44});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconSize = (diameter * 0.44).clamp(16.0, 24.0);
    final broadcastIconColor = AppTheme.liveStreamBroadcastIconColor(
      brightness,
    );
    final spinnerColor = broadcastIconColor;
    return ListenableBuilder(
      listenable: Listenable.merge([
        bibleFmWebPlaybackActive,
        bibleFmWebLiveReloading,
        bibleFmWebLiveEdgeActive,
      ]),
      builder: (context, _) {
        final playing = bibleFmWebPlaybackActive.value;
        final reloading = bibleFmWebLiveReloading.value;
        final atLiveEdge = bibleFmWebLiveEdgeActive.value;
        final isLive = playing && atLiveEdge;
        final canTap = !reloading && !isLive;
        // En direct / en écoute / «connexion…» (reloading): disco sempre transparente (anel + ícone/spinner).
        const discFill = Colors.transparent;
        final ringColor = AppTheme.transportLiveBorder(
          brightness,
        ).withValues(alpha: playing || reloading ? 0.65 : 0.45);

        String semanticsLabel;
        String tooltipMsg;
        if (reloading) {
          semanticsLabel = kBibleFmWebFrLiveA11yReloading;
          tooltipMsg = kBibleFmWebFrLiveTooltipReloading;
        } else if (playing && atLiveEdge) {
          semanticsLabel = kBibleFmWebFrLiveA11yActive;
          tooltipMsg = kBibleFmWebFrLiveTooltipActive;
        } else if (canTap) {
          semanticsLabel = kBibleFmWebFrLiveA11yGoLive;
          tooltipMsg = kBibleFmWebFrLiveTooltipGoLive;
        } else {
          semanticsLabel = kBibleFmWebFrLiveA11yPauseToEnable;
          tooltipMsg = kBibleFmWebFrLiveTooltipPauseToEnable;
        }

        final disc = InkWell(
          onTap: canTap
              ? () =>
                    unawaited(bibleFmWebReloadLiveStream(kBibleFmLiveStreamUrl))
              : null,
          customBorder: const CircleBorder(),
          hoverColor: canTap
              ? AppTheme.liveStreamButtonHover(brightness)
              : Colors.transparent,
          splashColor: canTap
              ? AppTheme.liveStreamButtonSplash(brightness)
              : Colors.transparent,
          highlightColor: canTap ? null : Colors.transparent,
          child: Ink(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: discFill,
              border: Border.all(color: ringColor, width: 1),
            ),
            child: Center(
              child: reloading
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        color: spinnerColor,
                        backgroundColor: spinnerColor.withValues(alpha: 0.2),
                      ),
                    )
                  : BroadcastSignalIcon(
                      color: broadcastIconColor,
                      size: iconSize,
                    ),
            ),
          ),
        );

        return Semantics(
          button: true,
          selected: isLive,
          enabled: canTap,
          label: semanticsLabel,
          child: Tooltip(
            message: tooltipMsg,
            waitDuration: const Duration(milliseconds: 320),
            child: MouseRegion(
              cursor: canTap
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Material(color: Colors.transparent, child: disc),
            ),
          ),
        );
      },
    );
  }
}

class _WebSleepTimerButton extends StatefulWidget {
  const _WebSleepTimerButton({super.key, this.controlHeight = 34});

  /// Alinhado à altura útil da cápsula (toque mais confortável no mobile web).
  final double controlHeight;

  @override
  State<_WebSleepTimerButton> createState() => _WebSleepTimerButtonState();
}

class _WebSleepTimerButtonState extends State<_WebSleepTimerButton> {
  Timer? _ticker;
  DateTime? _endAt;
  bool _sleepConfiguratorOpen = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void openFromScreenSwipe() {
    if (!mounted || _sleepConfiguratorOpen) return;
    // Mesmo comportamento do botão: gesto da tela delega para a intenção de abrir sleep.
    _openFromButtonIntent();
  }

  void _openFromButtonIntent() {
    if (!mounted || _sleepConfiguratorOpen) return;
    unawaited(_openSleepConfigurator());
  }

  int? get _remainingSec {
    final end = _endAt;
    if (end == null) return null;
    final diff = end.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _cancelSleepTimer() {
    _ticker?.cancel();
    _ticker = null;
    if (mounted) {
      setState(() {
        _endAt = null;
      });
    } else {
      _endAt = null;
    }
  }

  void _onTick() {
    if (!mounted) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    final remaining = _remainingSec;
    if (remaining == null) return;
    if (remaining == 0) {
      _cancelSleepTimer();
      bibleFmWebPausePlayback();
      return;
    }
    setState(() {});
  }

  void _startSleepTimer(int minutes) {
    if (minutes <= 0) return;
    _ticker?.cancel();
    _endAt = DateTime.now().add(Duration(minutes: minutes));
    if (!mounted) return;
    setState(() {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  String _labelFromRemaining() {
    final remaining = _remainingSec;
    if (remaining == null) return '';
    final hours = remaining ~/ 3600;
    final mins = (remaining % 3600) ~/ 60;
    final secs = remaining % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _openSleepConfigurator() async {
    if (_sleepConfiguratorOpen) return;
    _sleepConfiguratorOpen = true;
    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    final hoursFocus = FocusNode();
    final minutesFocus = FocusNode();

    int totalMinutesFromFields() {
      final h = int.tryParse(hoursController.text.trim()) ?? 0;
      final m = int.tryParse(minutesController.text.trim()) ?? 0;
      return h * 60 + m;
    }

    bool canApply() => totalMinutesFromFields() > 0;

    try {
      bibleFmWebSetSleepConfiguratorOpen(true);
      const gapBelowTransport = 12.0;

      /// Reserva vertical para manter a pílula visível (altura intrínseca ~64–88).
      const sleepBarViewportReserve = 92.0;

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final scheme = Theme.of(dialogContext).colorScheme;
          final brightness = scheme.brightness;
          // Sem blur: véu só a escurecer (mais opaco que o antigo com desfoque).
          final barrierAlpha = brightness == Brightness.dark ? 0.80 : 0.38;

          /// Altura útil da pílula H:M + botão (evita sobrepor o teclado no mobile).
          const estimatedSleepPanelHeight = 88.0;

          /// Margem mínima entre a pílula e o topo do teclado / borda inferior.
          const keyboardClearance = 10.0;

          void applyAndClose() {
            if (!canApply()) return;
            _startSleepTimer(totalMinutesFromFields());
            Navigator.of(dialogContext).pop();
          }

          void dismissOnly() {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(dialogContext).pop();
          }

          /// Toque simples no véu: só retira o foco dos dígitos (teclado / cursor).
          void onVeilSingleTap() {
            FocusManager.instance.primaryFocus?.unfocus();
          }

          /// Duplo toque no véu: valida e fecha se a duração for válida.
          void onVeilDoubleTap() {
            FocusManager.instance.primaryFocus?.unfocus();
            if (!canApply()) return;
            _startSleepTimer(totalMinutesFromFields());
            Navigator.of(dialogContext).pop();
          }

          /// Deslize rápido para cima: fecha sem aplicar (igual limiar do gesto sleep na página).
          void onSwipeUpClose(DragEndDetails details) {
            final vy = details.velocity.pixelsPerSecond.dy;
            if (vy < -180) {
              dismissOnly();
            }
          }

          // Builder: [MediaQuery.viewInsets] actualiza com o teclado virtual (mobile web / app).
          return Builder(
            builder: (overlayContext) {
              final mq = MediaQuery.of(overlayContext);
              final screenSize = mq.size;
              final safe = mq.padding;
              final keyboardBottom = mq.viewInsets.bottom;
              final minScreenPad = math.max(
                16.0,
                math.max(safe.left, safe.right),
              );
              final screenW = screenSize.width;
              final layoutSpec = _WebTransportLayoutSpec.compute(
                layoutW: screenW,
                layoutH: screenSize.height.isFinite ? screenSize.height : 0,
                textScaler: mq.textScaler,
              );
              // Mesma largura útil que a cápsula principal (barra de transporte).
              var targetW = layoutSpec.maxContentWidth;

              final capsuleBox =
                  _kWebTransportCapsule.currentContext?.findRenderObject()
                      as RenderBox?;
              double top;
              double left;
              if (capsuleBox != null &&
                  capsuleBox.hasSize &&
                  capsuleBox.attached) {
                targetW = capsuleBox.size.width;
                final origin = capsuleBox.localToGlobal(Offset.zero);
                top = origin.dy + capsuleBox.size.height + gapBelowTransport;
                left = origin.dx + (capsuleBox.size.width - targetW) / 2;
                left = left.clamp(
                  safe.left + 8.0,
                  screenW - targetW - safe.right - 8.0,
                );
                final maxTopNoKeyboard =
                    (screenSize.height -
                            sleepBarViewportReserve -
                            minScreenPad -
                            safe.bottom)
                        .clamp(safe.top + 8.0, double.infinity)
                        .toDouble();
                top = top.clamp(safe.top + 8.0, maxTopNoKeyboard);
              } else {
                top = screenSize.height * 0.42;
                left = (screenW - targetW) / 2;
                left = left.clamp(
                  safe.left + 8.0,
                  screenW - targetW - safe.right - 8.0,
                );
              }

              // Garantir que a pílula fica acima do teclado (área útil = ecrã − insets).
              final aboveKeyboardTop =
                  screenSize.height -
                  keyboardBottom -
                  estimatedSleepPanelHeight -
                  keyboardClearance;
              final maxTopWithKeyboard = math.min(
                aboveKeyboardTop,
                screenSize.height -
                    sleepBarViewportReserve -
                    minScreenPad -
                    safe.bottom,
              );
              top = top.clamp(
                safe.top + 8.0,
                maxTopWithKeyboard.clamp(safe.top + 8.0, double.infinity),
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: _SleepHmSwipeBand(
                      behavior: HitTestBehavior.opaque,
                      hoursFocus: hoursFocus,
                      minutesFocus: minutesFocus,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onVeilSingleTap,
                        onDoubleTap: onVeilDoubleTap,
                        onVerticalDragEnd: onSwipeUpClose,
                        child: ColoredBox(
                          color: scheme.scrim.withValues(alpha: barrierAlpha),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    top: top,
                    left: left,
                    width: targetW,
                    child: Material(
                      type: MaterialType.transparency,
                      child: StatefulBuilder(
                        builder: (context, setLocalState) {
                          final valid = canApply();
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragEnd: onSwipeUpClose,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    6,
                                    6,
                                    6,
                                  ),
                                  child: _SleepHmSwipeBand(
                                    hoursFocus: hoursFocus,
                                    minutesFocus: minutesFocus,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: _SleepHmUnderlineFields(
                                            hoursController: hoursController,
                                            minutesController:
                                                minutesController,
                                            hoursFocus: hoursFocus,
                                            minutesFocus: minutesFocus,
                                            onChanged: () =>
                                                setLocalState(() {}),
                                            onHoursSubmitted: () =>
                                                minutesFocus.requestFocus(),
                                            onMinutesSubmitted: applyAndClose,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        _SleepActionButton(
                                          cancelMode: false,
                                          enabled: valid,
                                          onTap: () {
                                            if (!canApply()) return;
                                            _startSleepTimer(
                                              totalMinutesFromFields(),
                                            );
                                            Navigator.of(dialogContext).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      bibleFmWebSetSleepConfiguratorOpen(false);
      _sleepConfiguratorOpen = false;
      final hc = hoursController;
      final mc = minutesController;
      final hf = hoursFocus;
      final mf = minutesFocus;
      // Adia dispose até a rota desmontar : dispose síncrono no `finally`
      // pode libertar Focus/TextField antes do fim do deactivate e falhar
      // `'_dependents.isEmpty': is not true`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        hc.dispose();
        mc.dispose();
        hf.dispose();
        mf.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTimer = _endAt != null;
    final brightness = Theme.of(context).brightness;
    final ring = AppTheme.transportLiveBorder(
      brightness,
    ).withValues(alpha: hasTimer ? 0.65 : 0.45);
    final h = widget.controlHeight;
    final radius = h / 2;
    final padH = (h * 0.28).clamp(8.0, 14.0);
    final iconMain = (h * 0.45).clamp(16.0, 22.0);
    final iconClose = (h * 0.4).clamp(14.0, 18.0);
    final gapSm = (h * 0.1).clamp(3.0, 6.0);
    final iconInk = AppTheme.liveStreamBroadcastIconColor(brightness);

    return Semantics(
      button: true,
      label: kBibleFmWebFrSleepA11y,
      child: Tooltip(
        message: hasTimer ? _labelFromRemaining() : kBibleFmWebFrSleepTooltip,
        waitDuration: const Duration(milliseconds: 280),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openFromButtonIntent,
            borderRadius: BorderRadius.circular(radius),
            hoverColor: AppTheme.liveStreamButtonHover(brightness),
            splashColor: AppTheme.liveStreamButtonSplash(brightness),
            highlightColor: null,
            child: Ink(
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: ring, width: 1),
                color: Colors.transparent,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padH),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: iconMain, color: iconInk),
                    if (hasTimer) ...[
                      SizedBox(width: gapSm),
                      Text(
                        _labelFromRemaining(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: iconInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: gapSm),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _cancelSleepTimer,
                        child: Icon(
                          Icons.close_rounded,
                          size: iconClose,
                          color: iconInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Swipe horizontal : droite / fling positif → minute, gauche → heure (véu ou pílula).
void _sleepHmApplyHorizontalSwipe({
  required double velocityX,
  required double dragDx,
  required FocusNode hoursFocus,
  required FocusNode minutesFocus,
}) {
  const minDist = 28.0;
  const minVel = 140.0;
  final useVel = velocityX.abs() >= minVel;
  if (useVel) {
    if (velocityX > 0) {
      minutesFocus.requestFocus();
    } else {
      hoursFocus.requestFocus();
    }
    return;
  }
  if (dragDx.abs() < minDist) return;
  if (dragDx > 0) {
    minutesFocus.requestFocus();
  } else {
    hoursFocus.requestFocus();
  }
}

/// Zone avec détection du swipe horizontal (toute la tela do temporizador ou barre H:M).
class _SleepHmSwipeBand extends StatefulWidget {
  const _SleepHmSwipeBand({
    required this.hoursFocus,
    required this.minutesFocus,
    required this.child,
    this.behavior = HitTestBehavior.translucent,
  });

  final FocusNode hoursFocus;
  final FocusNode minutesFocus;
  final Widget child;
  final HitTestBehavior behavior;

  @override
  State<_SleepHmSwipeBand> createState() => _SleepHmSwipeBandState();
}

class _SleepHmSwipeBandState extends State<_SleepHmSwipeBand> {
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onHorizontalDragStart: (_) {
        _dragDx = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDx += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        _sleepHmApplyHorizontalSwipe(
          velocityX: details.velocity.pixelsPerSecond.dx,
          dragDx: _dragDx,
          hoursFocus: widget.hoursFocus,
          minutesFocus: widget.minutesFocus,
        );
        _dragDx = 0;
      },
      onHorizontalDragCancel: () {
        _dragDx = 0;
      },
      child: widget.child,
    );
  }
}

/// Saisie H:M — swipe gauche = heures, droite = minutes ; trait + gras sur le champ actif.
class _SleepHmUnderlineFields extends StatefulWidget {
  const _SleepHmUnderlineFields({
    required this.hoursController,
    required this.minutesController,
    required this.hoursFocus,
    required this.minutesFocus,
    required this.onChanged,
    required this.onHoursSubmitted,
    required this.onMinutesSubmitted,
  });

  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final FocusNode hoursFocus;
  final FocusNode minutesFocus;
  final VoidCallback onChanged;
  final VoidCallback onHoursSubmitted;
  final VoidCallback onMinutesSubmitted;

  static const double _colonTrack = 12;

  @override
  State<_SleepHmUnderlineFields> createState() =>
      _SleepHmUnderlineFieldsState();
}

class _SleepHmUnderlineFieldsState extends State<_SleepHmUnderlineFields> {
  @override
  void initState() {
    super.initState();
    widget.hoursFocus.addListener(_onFocusChanged);
    widget.minutesFocus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _SleepHmUnderlineFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hoursFocus != widget.hoursFocus) {
      oldWidget.hoursFocus.removeListener(_onFocusChanged);
      widget.hoursFocus.addListener(_onFocusChanged);
    }
    if (oldWidget.minutesFocus != widget.minutesFocus) {
      oldWidget.minutesFocus.removeListener(_onFocusChanged);
      widget.minutesFocus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.hoursFocus.removeListener(_onFocusChanged);
    widget.minutesFocus.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hoursFocused = widget.hoursFocus.hasFocus;
    final minutesFocused = widget.minutesFocus.hasFocus;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    // Escuro sobre fundo preto/carvão: cinzas claros para contraste alto (sem contorno na pílula).
    final ink = isDark ? const Color(0xFFFAFAFA) : scheme.onSurface;
    final inkMuted = isDark ? const Color(0xFFE4E4E7) : scheme.onSurfaceVariant;
    const digitSize = 19.0;
    final digitInactive = TextStyle(
      color: ink,
      fontWeight: FontWeight.w500,
      fontSize: digitSize,
      height: 1.0,
    );
    final digitActive = digitInactive.copyWith(fontWeight: FontWeight.w800);
    final colonStyle = digitInactive.copyWith(fontWeight: FontWeight.w600);

    final labelMuted = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: isDark ? inkMuted : inkMuted.withValues(alpha: 0.88),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.0,
    );
    final labelStrong =
        labelMuted?.copyWith(fontWeight: FontWeight.w800) ??
        const TextStyle(fontWeight: FontWeight.w800);

    final barStrong = isDark
        ? Colors.white.withValues(alpha: 0.52)
        : ink.withValues(alpha: 0.35);
    final barSoft = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : ink.withValues(alpha: 0.12);

    InputDecoration deco(String hint, {required bool focused}) =>
        InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark
                ? const Color(0xFFA1A1AA)
                : ink.withValues(alpha: 0.38),
            fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
            fontSize: digitSize,
            height: 1.0,
          ),
          isDense: true,
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(bottom: 4, top: 0),
        );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: TextField(
                controller: widget.hoursController,
                focusNode: widget.hoursFocus,
                autofocus: true,
                maxLines: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                style: hoursFocused ? digitActive : digitInactive,
                cursorColor: ink,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: deco(
                  kBibleFmWebFrSleepPlaceholderDigits,
                  focused: hoursFocused,
                ),
                onChanged: (v) {
                  if (v.length >= 2 && !widget.minutesFocus.hasFocus) {
                    widget.minutesFocus.requestFocus();
                  }
                  widget.onChanged();
                },
                onSubmitted: (_) => widget.onHoursSubmitted(),
              ),
            ),
            SizedBox(
              width: _SleepHmUnderlineFields._colonTrack,
              child: Center(child: Text(':', style: colonStyle)),
            ),
            Expanded(
              child: TextField(
                controller: widget.minutesController,
                focusNode: widget.minutesFocus,
                maxLines: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                style: minutesFocused ? digitActive : digitInactive,
                cursorColor: ink,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: deco(
                  kBibleFmWebFrSleepPlaceholderDigits,
                  focused: minutesFocused,
                ),
                onChanged: (v) {
                  final raw = int.tryParse(v);
                  if (raw != null && raw > 59) {
                    const fixed = '59';
                    widget.minutesController.value = widget
                        .minutesController
                        .value
                        .copyWith(
                          text: fixed,
                          selection: const TextSelection.collapsed(
                            offset: fixed.length,
                          ),
                          composing: TextRange.empty,
                        );
                  }
                  widget.onChanged();
                },
                onSubmitted: (_) => widget.onMinutesSubmitted(),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: hoursFocused ? barStrong : barSoft,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _SleepHmUnderlineFields._colonTrack),
                  Expanded(
                    child: SizedBox(
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: minutesFocused ? barStrong : barSoft,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.hoursFocus.requestFocus(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            kBibleFmWebFrSleepLabelHeure,
                            style: hoursFocused ? labelStrong : labelMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _SleepHmUnderlineFields._colonTrack),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.minutesFocus.requestFocus(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            kBibleFmWebFrSleepLabelMinute,
                            style: minutesFocused ? labelStrong : labelMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Semantics(
      label: kBibleFmWebFrSleepInputHint,
      child: LayoutBuilder(
        builder: (context, c) {
          // Ecrãs muito estreitos: encolhe o bloco H:M sem estourar a pílula.
          if (c.maxWidth < 200) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth),
                child: column,
              ),
            );
          }
          return column;
        },
      ),
    );
  }
}

class _SleepActionButton extends StatelessWidget {
  const _SleepActionButton({
    required this.cancelMode,
    this.enabled = true,
    required this.onTap,
  });

  final bool cancelMode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = scheme.brightness;
    final iconInk = AppTheme.liveStreamBroadcastIconColor(brightness);
    final mutedRing =
        AppTheme.transportLiveBorder(brightness).withValues(alpha: 0.28);

    late final Color ringColor;
    late final Color iconColor;
    late final IconData iconData;
    late final double iconSize;
    late final Color hoverColor;
    late final Color splashColor;

    if (cancelMode) {
      ringColor =
          enabled ? AppTheme.transportCapsuleOutline(brightness) : mutedRing;
      iconColor = enabled ? iconInk : iconInk.withValues(alpha: 0.38);
      iconData = Icons.close_rounded;
      iconSize = 20;
      hoverColor =
          enabled ? AppTheme.liveStreamButtonHover(brightness) : Colors.transparent;
      splashColor =
          enabled ? AppTheme.liveStreamButtonSplash(brightness) : Colors.transparent;
    } else {
      // Confirmar: ícone Material (task_alt, estilo Google) + cor primária.
      ringColor = enabled ? scheme.primary.withValues(alpha: 0.9) : mutedRing;
      iconColor =
          enabled ? scheme.primary : scheme.onSurface.withValues(alpha: 0.38);
      iconData = Icons.task_alt;
      iconSize = 22;
      hoverColor =
          enabled ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent;
      splashColor =
          enabled ? scheme.primary.withValues(alpha: 0.24) : Colors.transparent;
    }

    const dim = 36.0;
    final radius = dim / 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: hoverColor,
        splashColor: splashColor,
        highlightColor: enabled ? null : Colors.transparent,
        child: Ink(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: ringColor, width: 1),
          ),
          child: Icon(
            iconData,
            size: iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

// Fundo visual da página agora é desenhado directamente via [Ink] no `Stack`,
// alinhado com os gradientes e superfícies em [AppTheme].
