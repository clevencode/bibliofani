import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';
import 'package:meu_app/features/radio/widgets/web_native_audio.dart';

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
                          decoration: BoxDecoration(
                            color: AppTheme.transportCapsuleTrack(brightness),
                            borderRadius: BorderRadius.circular(
                              webCapsuleH / 2,
                            ),
                            border: Border.all(
                              color: AppTheme.transportLiveBorder(brightness)
                                  .withValues(
                                    alpha: brightness == Brightness.dark
                                        ? 0.35
                                        : 0.5,
                                  ),
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
                                  const _WebSleepTimerButton(),
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
  const _WebSleepTimerButton();

  @override
  State<_WebSleepTimerButton> createState() => _WebSleepTimerButtonState();
}

enum _SleepInputUnit { hour, minute }

class _WebSleepTimerButtonState extends State<_WebSleepTimerButton> {
  Timer? _ticker;
  DateTime? _endAt;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
    final hasTimer = _endAt != null;
    final inputController = TextEditingController();
    var unit = _SleepInputUnit.minute;
    bool canApply() {
      final raw = int.tryParse(inputController.text.trim()) ?? 0;
      return raw > 0;
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          final brightness = Theme.of(dialogContext).brightness;
          final screenW = MediaQuery.sizeOf(dialogContext).width;
          final targetW = (screenW - 48).clamp(280.0, 560.0).toDouble();
          const webCapsuleH = 52.0;
          return Align(
            // Alinha no mesmo eixo vertical da cápsula de audio control (efeito de sobreposição).
            alignment: const Alignment(0, 0.12),
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.transparent,
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  final valid = canApply();
                  return SizedBox(
                    width: targetW,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.transportCapsuleTrack(brightness),
                        borderRadius: BorderRadius.circular(webCapsuleH / 2),
                        border: Border.all(
                          color: AppTheme.transportLiveBorder(brightness)
                              .withValues(
                                alpha: brightness == Brightness.dark
                                    ? 0.35
                                    : 0.65,
                              ),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            _SleepUnitChip(
                              label: 'Heure',
                              selected: unit == _SleepInputUnit.hour,
                              onTap: () => setLocalState(
                                () => unit = _SleepInputUnit.hour,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SleepUnitChip(
                              label: 'Minute',
                              selected: unit == _SleepInputUnit.minute,
                              onTap: () => setLocalState(
                                () => unit = _SleepInputUnit.minute,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SleepChipField(
                                width: 180,
                                hintText: kBibleFmWebFrSleepInputHint,
                                label: kBibleFmWebFrSleepInputHint,
                                controller: inputController,
                                autofocus: true,
                                onChanged: (_) => setLocalState(() {}),
                                onSubmitted: (_) {
                                  if (hasTimer || !canApply()) return;
                                  final raw =
                                      int.tryParse(inputController.text.trim()) ?? 0;
                                  final minutes = unit == _SleepInputUnit.hour
                                      ? raw * 60
                                      : raw;
                                  _startSleepTimer(minutes);
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SleepActionButton(
                              cancelMode: false,
                              enabled: valid,
                              onTap: () {
                                final raw =
                                    int.tryParse(inputController.text.trim()) ?? 0;
                                if (raw <= 0) return;
                                final minutes = unit == _SleepInputUnit.hour
                                    ? raw * 60
                                    : raw;
                                _startSleepTimer(minutes);
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
          );
        },
      );
    } finally {
      inputController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTimer = _endAt != null;
    final brightness = Theme.of(context).brightness;
    final fg = Theme.of(context).colorScheme.onSurfaceVariant;
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
          onTap: () => unawaited(_openSleepConfigurator()),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ring, width: 1),
              color: hasTimer ? fg.withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_outlined, size: 17, color: fg),
                if (hasTimer) ...[
                  const SizedBox(width: 4),
                  Text(
                    _labelFromRemaining(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelSleepTimer,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: fg.withValues(alpha: 0.9),
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

class _SleepUnitChip extends StatelessWidget {
  const _SleepUnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final rim = AppTheme.transportLiveBorder(brightness);
    final onChrome = AppTheme.transportChromeOnInner(brightness);
    final chromeInner = AppTheme.transportChromeInnerFill(brightness);
    final chipFill = selected
        ? chromeInner
        : chromeInner.withValues(
            alpha: brightness == Brightness.light ? 0.82 : 0.88,
          );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: chipFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.transportChromeTimelineTrack(brightness)
                    .withValues(alpha: brightness == Brightness.light ? 0.72 : 0.55)
                : rim.withValues(alpha: brightness == Brightness.light ? 0.55 : 0.42),
            width: selected && brightness == Brightness.light ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? Colors.black : Colors.transparent,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: onChrome,
                      fontWeight: FontWeight.normal,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepChipField extends StatelessWidget {
  const _SleepChipField({
    required this.width,
    this.hintText,
    this.label,
    required this.controller,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final double width;
  // Mantido para compatibilidade com hot reload após refactor.
  final String? hintText;
  // Campo legado mantido para evitar "Const class cannot remove fields".
  final String? label;
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final onChrome = AppTheme.transportChromeOnInner(brightness);
    final chromeInner = AppTheme.transportChromeInnerFill(brightness);
    final radius = BorderRadius.circular(20);
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: chromeInner,
                borderRadius: radius,
                border: Border.all(
                  color:
                      AppTheme.transportChromeTimelineTrack(brightness).withValues(
                    alpha: brightness == Brightness.light ? 0.75 : 0.55,
                  ),
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(
                          alpha: brightness == Brightness.light ? 0.07 : 0.1,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42],
                    ),
                  ),
                ),
              ),
            ),
            TextField(
              controller: controller,
              autofocus: autofocus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              cursorColor: onChrome,
              style: TextStyle(
                color: onChrome,
                fontWeight: FontWeight.w600,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hintText ?? label ?? '',
                hintStyle: TextStyle(
                  color: onChrome.withValues(
                    alpha: brightness == Brightness.light ? 0.48 : 0.45,
                  ),
                ),
                filled: true,
                fillColor: Colors.transparent,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
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
    final brightness = Theme.of(context).brightness;
    final onChrome = AppTheme.transportChromeOnInner(brightness);
    final rim = AppTheme.transportChromeTimelineTrack(brightness);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: brightness == Brightness.light && enabled
              ? AppTheme.transportChromeInnerFill(brightness)
              : null,
          border: Border.all(
            color: rim.withValues(alpha: enabled ? 0.72 : 0.35),
            width: brightness == Brightness.light ? 1.25 : 1,
          ),
        ),
        child: Icon(
          cancelMode ? Icons.close_rounded : Icons.check_rounded,
          size: 26,
          color: enabled ? onChrome : onChrome.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

// Fundo visual da página agora é desenhado directamente via [Ink] no `Stack`,
// alinhado com os gradientes e superfícies em [AppTheme].
