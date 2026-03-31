import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';
import 'package:meu_app/features/radio/widgets/web_native_audio.dart';

/// Ancora visual: barra do temporizador alinha logo abaixo desta cápsula.
final GlobalKey _kWebTransportCapsule = GlobalKey(debugLabel: 'webTransportCapsule');
/// Referência ao botão de sleep para acionar o mesmo fluxo do clique.
final GlobalKey<_WebSleepTimerButtonState> _kWebSleepTimerButtonKey =
    GlobalKey<_WebSleepTimerButtonState>(debugLabel: 'webSleepTimerButton');

/// Bible FM — leitor **apenas Web** (`<audio controls>` + botão directo).
class RadioPlayerPage extends StatelessWidget {
  const RadioPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const webCapsuleH = 52.0;
    const webPadH = 8.0;
    const webPadV = 5.0;
    const webLiveDiameter = 42.0;
    const webAudioH = 40.0;
    final innerH = webCapsuleH - 2 * webPadV;
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
            SafeArea(
              // Deslize rápido para baixo em qualquer ponto desta zona (tela útil)
              // abre o temporizador — mesmo fluxo do botão.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (details) {
                  final vy = details.velocity.pixelsPerSecond.dy;
                  if (vy > 180) {
                    _kWebSleepTimerButtonKey.currentState
                        ?.openFromScreenSwipe();
                  }
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _WebRealtimeFeedbackLine(),
                          const SizedBox(height: 16),
                          DecoratedBox(
                            key: _kWebTransportCapsule,
                            decoration: BoxDecoration(
                              color: AppTheme.transportCapsuleTrack(brightness),
                              borderRadius: BorderRadius.circular(
                                webCapsuleH / 2,
                              ),
                              border: Border.all(
                                color:
                                    AppTheme.transportCapsuleOutline(brightness),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                webPadH,
                                webPadV,
                                webPadH,
                                webPadV,
                              ),
                              child: SizedBox(
                                height: innerH,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const _WebLiveStreamButton(
                                      diameter: webLiveDiameter,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: WebNativeAudioControls(
                                        streamUrl: kBibleFmLiveStreamUrl,
                                        controlsHeight: webAudioH,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _WebSleepTimerButton(
                                      key: _kWebSleepTimerButtonKey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
  const _WebRealtimeFeedbackLine();

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

        return Semantics(
          liveRegion: true,
          label: msg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showOnAirDot) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onAirColor,
                    boxShadow: [
                      BoxShadow(
                        color: onAirColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
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
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(
                    msg,
                    key: ValueKey<String>(msg),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
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
        final isListening = playing && !atLiveEdge;
        final canTap = !reloading && !isLive;
        final discFill =
            isLive || reloading
                ? AppTheme.liveStreamDiscFill(brightness)
                : isListening
                ? AppTheme.liveStreamDiscFill(brightness).withValues(alpha: 0.5)
                : Colors.transparent;
        final ringColor = AppTheme.transportLiveBorder(brightness).withValues(
          alpha: playing || reloading ? 0.65 : 0.45,
        );

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
              border: Border.all(
                color: ringColor,
                width: 1,
              ),
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
  const _WebSleepTimerButton({super.key});

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
      const gapBelowTransport = 12.0;
      const minScreenPad = 16.0;
      /// Reserva vertical para manter a pílula visível (altura intrínseca ~64–88).
      const sleepBarViewportReserve = 92.0;

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final scheme = Theme.of(dialogContext).colorScheme;
          final brightness = scheme.brightness;
          final barrierAlpha = brightness == Brightness.dark ? 0.18 : 0.10;
          final screenSize = MediaQuery.sizeOf(dialogContext);
          final screenW = screenSize.width;
          final targetW = (screenW - 48).clamp(280.0, 560.0).toDouble();

          final capsuleBox =
              _kWebTransportCapsule.currentContext?.findRenderObject()
                  as RenderBox?;
          double top;
          double left;
          if (capsuleBox != null && capsuleBox.hasSize && capsuleBox.attached) {
            final origin = capsuleBox.localToGlobal(Offset.zero);
            top = origin.dy + capsuleBox.size.height + gapBelowTransport;
            left = origin.dx + (capsuleBox.size.width - targetW) / 2;
            left = left.clamp(minScreenPad, screenW - targetW - minScreenPad);
            final maxTop = (screenSize.height -
                    sleepBarViewportReserve -
                    minScreenPad)
                .clamp(minScreenPad, double.infinity)
                .toDouble();
            top = top.clamp(minScreenPad, maxTop);
          } else {
            top = screenSize.height * 0.42;
            left = (screenW - targetW) / 2;
          }

          void applyAndClose() {
            if (!canApply()) return;
            _startSleepTimer(totalMinutesFromFields());
            Navigator.of(dialogContext).pop();
          }

          return Theme(
            data: Theme.of(dialogContext),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Véu em ecrã inteiro: toque fecha (o barrier do dialog fica por baixo e não recebe o hit).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(dialogContext).pop();
                    },
                    child: ColoredBox(
                      color: scheme.scrim.withValues(alpha: barrierAlpha),
                    ),
                  ),
                ),
                Positioned(
                  top: top,
                  left: left,
                  width: targetW,
                  child: Material(
                    type: MaterialType.transparency,
                    child: StatefulBuilder(
                      builder: (context, setLocalState) {
                        final valid = canApply();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _SleepHmUnderlineFields(
                                      hoursController: hoursController,
                                      minutesController: minutesController,
                                      hoursFocus: hoursFocus,
                                      minutesFocus: minutesFocus,
                                      onChanged: () => setLocalState(() {}),
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
                                    _startSleepTimer(totalMinutesFromFields());
                                    Navigator.of(dialogContext).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              ],
            ),
          );
        },
      );
    } finally {
      hoursController.dispose();
      minutesController.dispose();
      hoursFocus.dispose();
      minutesFocus.dispose();
      _sleepConfiguratorOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTimer = _endAt != null;
    final brightness = Theme.of(context).brightness;
    final ring = AppTheme.transportLiveBorder(brightness).withValues(
      alpha: hasTimer ? 0.65 : 0.45,
    );

    return Semantics(
      button: true,
      label: kBibleFmWebFrSleepA11y,
      child: Tooltip(
        message: hasTimer ? _labelFromRemaining() : kBibleFmWebFrSleepTooltip,
        waitDuration: const Duration(milliseconds: 280),
        child: InkWell(
          onTap: _openFromButtonIntent,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ring, width: 1),
              color: hasTimer
                  ? AppTheme.liveStreamDiscFill(brightness)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 17, color: Colors.black),
                if (hasTimer) ...[
                  const SizedBox(width: 4),
                  Text(
                    _labelFromRemaining(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelSleepTimer,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zone ligne + H/M : swipe horizontal pour basculer le focus (évite le conflit avec les TextField).
class _SleepHmSwipeBand extends StatefulWidget {
  const _SleepHmSwipeBand({
    required this.hoursFocus,
    required this.minutesFocus,
    required this.child,
  });

  final FocusNode hoursFocus;
  final FocusNode minutesFocus;
  final Widget child;

  @override
  State<_SleepHmSwipeBand> createState() => _SleepHmSwipeBandState();
}

class _SleepHmSwipeBandState extends State<_SleepHmSwipeBand> {
  double _dragDx = 0;

  void _commitSwipe(double velocityX) {
    const minDist = 28.0;
    const minVel = 140.0;
    final useVel = velocityX.abs() >= minVel;
    if (useVel) {
      if (velocityX > 0) {
        widget.minutesFocus.requestFocus();
      } else {
        widget.hoursFocus.requestFocus();
      }
      return;
    }
    if (_dragDx.abs() < minDist) return;
    if (_dragDx > 0) {
      widget.minutesFocus.requestFocus();
    } else {
      widget.hoursFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _dragDx = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDx += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        _commitSwipe(details.velocity.pixelsPerSecond.dx);
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
    final inkMuted =
        isDark ? const Color(0xFFE4E4E7) : scheme.onSurfaceVariant;
    const digitSize = 19.0;
    final digitInactive = TextStyle(
      color: ink,
      fontWeight: FontWeight.w500,
      fontSize: digitSize,
      height: 1.0,
    );
    final digitActive =
        digitInactive.copyWith(fontWeight: FontWeight.w800);
    final colonStyle = digitInactive.copyWith(fontWeight: FontWeight.w600);

    final labelMuted = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? inkMuted : inkMuted.withValues(alpha: 0.88),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 1.0,
        );
    final labelStrong = labelMuted?.copyWith(fontWeight: FontWeight.w800) ??
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
                    widget.minutesController.value =
                        widget.minutesController.value.copyWith(
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
                            style:
                                minutesFocused ? labelStrong : labelMuted,
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

    final fields = _SleepHmSwipeBand(
      hoursFocus: widget.hoursFocus,
      minutesFocus: widget.minutesFocus,
      child: column,
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
                child: fields,
              ),
            );
          }
          return fields;
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
    final isDark = scheme.brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFFAFAFA) : scheme.onSurface;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Icon(
          cancelMode ? Icons.close_rounded : Icons.check_circle,
          size: 22,
          color: enabled ? ink : ink.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

// Fundo visual da página agora é desenhado directamente via [Ink] no `Stack`,
// alinhado com os gradientes e superfícies em [AppTheme].
