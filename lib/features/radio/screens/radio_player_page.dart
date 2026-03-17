import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

class RadioPlayerPage extends ConsumerWidget {
  const RadioPlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uiAccent = scheme.primary;
    final pageBg = isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F6F8);
    final panelA = isDark
        ? const Color(0xF7151820)
        : const Color(0xF7FFFFFF);
    final panelB = isDark
        ? const Color(0xEB10131A)
        : const Color(0xEBF8FAFC);
    final state = ref.watch(radioPlayerProvider);
    final notifier = ref.read(radioPlayerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(color: pageBg),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.25,
                colors: [
                  uiAccent.withValues(alpha: 0.06),
                  scheme.secondary.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: isDark ? 0.66 : 0.66,
                  ),
                  Colors.transparent,
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: isDark ? 0.72 : 0.72,
                  ),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompactHeight = constraints.maxHeight < 720;
                final isNarrow = constraints.maxWidth < 360;
                final isLandscape = constraints.maxWidth > constraints.maxHeight;
                final scale = _mobileScale(
                  constraints.biggest.shortestSide,
                );
                final sidePadding = (isNarrow ? 12.0 : 16.0) * scale;
                final panelPadding = (isNarrow ? 16.0 : 20.0) * scale;
                final panelWidth = isLandscape
                    ? constraints.maxWidth * 0.74
                    : (constraints.maxWidth >= 600 ? 460.0 : 440.0) * scale;
                final playButtonSize = isNarrow
                    ? 104.0 * scale
                    : isCompactHeight
                        ? 116.0 * scale
                        : 126.0 * scale;
                final bottomInset = MediaQuery.paddingOf(context).bottom;
                final distributeSections =
                    !isCompactHeight && constraints.maxHeight >= 760;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    8,
                    sidePadding,
                    isCompactHeight ? 10 : 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isCompactHeight ? 18 : 24),
                    ),
                    child: Column(
                      mainAxisAlignment: distributeSections
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BibleFmCover(
                          scale: scale,
                          isActive:
                              state.isLiveMode || state.isPlaying || state.isBuffering,
                        ),
                        SizedBox(height: (isCompactHeight ? 14 : 22) * scale),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24 * scale),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10 * scale,
                                sigmaY: 10 * scale,
                              ),
                              child: Container(
                                width: constraints.maxWidth.clamp(
                                  280.0,
                                  panelWidth,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: panelPadding,
                                  vertical: (isCompactHeight ? 18 : 26) * scale,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      panelA,
                                      panelB,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24 * scale),
                                  border: Border.all(
                                    color: (isDark ? uiAccent : scheme.outline).withValues(
                                      alpha: isDark ? 0.42 : 0.78,
                                    ),
                                    width: 1.1 * scale,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? Colors.black : Colors.black87)
                                          .withValues(alpha: isDark ? 0.18 : 0.12),
                                      blurRadius: 30 * scale,
                                      offset: Offset(0, 12 * scale),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PlaybackStatusChip(
                                      isPlaying: state.isPlaying,
                                      isBuffering: state.isBuffering,
                                      isLiveMode: state.isLiveMode,
                                      scale: scale,
                                    ),
                                    SizedBox(height: (isCompactHeight ? 16 : 24) * scale),
                                    DurationLabel(elapsed: state.elapsed, scale: scale),
                                    SizedBox(height: 6 * scale),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (state.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                            child: Text(
                              state.errorMessage!,
                              style: GoogleFonts.dmSans(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.w700,
                                color: scheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          height: (distributeSections ? 10 : (isCompactHeight ? 18 : 28)) *
                              scale,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LiveIconButton(
                              isLiveMode: state.isLiveMode,
                              onLiveTap: notifier.goLive,
                              scale: scale,
                            ),
                            SizedBox(height: (isCompactHeight ? 18 : 24) * scale),
                            PlayButton(
                              isPlaying: state.isPlaying,
                              isLoading: state.isBuffering,
                              onTap: notifier.togglePlayPause,
                              size: playButtonSize,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: ((isCompactHeight ? 10 : 18) * scale) + bottomInset,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BibleFmCover extends StatelessWidget {
  const BibleFmCover({
    super.key,
    required this.scale,
    required this.isActive,
  });

  final double scale;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final uiAccent = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 360;
    final titleFont = ((size.width * 0.1) * scale).clamp(27.0, 42.0);
    final iconSize = ((size.width * 0.07) * scale).clamp(20.0, 30.0);
    final coverHeight = ((size.height * 0.11) * scale).clamp(72.0, 96.0);

    return SizedBox(
      width: double.infinity,
      height: coverHeight,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: (isNarrow ? 16 : 22) * scale,
          vertical: 12 * scale,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xE6151820)
              : Colors.white,
          borderRadius: BorderRadius.circular(20 * scale),
          border: Border.all(
            color: uiAccent.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.18),
            width: 1.2 * scale,
          ),
          boxShadow: [
            BoxShadow(
              color: uiAccent.withValues(alpha: 0.15),
              blurRadius: 16 * scale,
              offset: Offset(0, 6 * scale),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              'BIBLE FM',
              style: GoogleFonts.russoOne(
                color: uiAccent,
                fontSize: titleFont,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            _AnimatedEqBadge(
              size: 38 * scale,
              iconSize: iconSize,
              color: uiAccent,
              isActive: isActive,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedEqBadge extends StatefulWidget {
  const _AnimatedEqBadge({
    required this.size,
    required this.iconSize,
    required this.color,
    required this.isActive,
  });

  final double size;
  final double iconSize;
  final Color color;
  final bool isActive;

  @override
  State<_AnimatedEqBadge> createState() => _AnimatedEqBadgeState();
}

class _AnimatedEqBadgeState extends State<_AnimatedEqBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedEqBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final waveSize = widget.iconSize * 0.82;
        final barWidth = math.max(2.2, waveSize * 0.12);
        final minBar = waveSize * 0.22;
        final maxBar = waveSize * 0.88;
        double barHeight(double phase) {
          if (!widget.isActive) return waveSize * 0.38;
          final value = (math.sin((t * math.pi * 2) + phase) + 1) / 2;
          return minBar + ((maxBar - minBar) * value);
        }

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SpeechBar(
                  height: barHeight(0),
                  width: barWidth,
                  color: widget.color,
                ),
                SizedBox(width: barWidth * 0.8),
                _SpeechBar(
                  height: barHeight(math.pi / 2),
                  width: barWidth,
                  color: widget.color,
                ),
                SizedBox(width: barWidth * 0.8),
                _SpeechBar(
                  height: barHeight(math.pi),
                  width: barWidth,
                  color: widget.color,
                ),
                SizedBox(width: barWidth * 0.8),
                _SpeechBar(
                  height: barHeight((math.pi * 3) / 2),
                  width: barWidth,
                  color: widget.color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpeechBar extends StatelessWidget {
  const _SpeechBar({
    required this.height,
    required this.width,
    required this.color,
  });

  final double height;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(width),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.scale,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final uiAccent = Theme.of(context).colorScheme.primary;
    final isListening = isPlaying && !isBuffering;
    final isLive = isListening && isLiveMode;
    final color = isLive
        ? const Color(0xFF148A37)
        : uiAccent.withValues(alpha: 0.92);
    final label = isBuffering
        ? 'Connexion'
        : isLive
            ? 'En direct'
            : isListening
                ? 'En écoute'
                : 'En pause';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xD3131620)
            : Colors.white,
        borderRadius: BorderRadius.circular(999 * scale),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBuffering ? Icons.sync_rounded : Icons.fiber_manual_record_rounded,
            size: 14 * scale,
            color: color,
          ),
          SizedBox(width: 8 * scale),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 12 * scale,
              letterSpacing: 0.8 * scale,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveIconButton extends StatelessWidget {
  const LiveIconButton({
    super.key,
    required this.isLiveMode,
    required this.onLiveTap,
    required this.scale,
  });

  final bool isLiveMode;
  final VoidCallback onLiveTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final uiAccent = Theme.of(context).colorScheme.primary;
    final borderColor = isLiveMode
        ? const Color(0xFFB50000)
        : uiAccent.withValues(alpha: 0.28);
    final backgroundColor = isLiveMode
        ? const Color(0x66B50000)
        : (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xE6131620)
            : Colors.white);
    final textColor = isLiveMode ? const Color(0xFFFF7A7A) : uiAccent;
    final buttonSize = 46 * scale;

    return Semantics(
      button: true,
      label: 'Mode direct',
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonSize),
        onTap: onLiveTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: buttonSize,
          height: buttonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.25 * scale),
            boxShadow: [
              BoxShadow(
                color: (isLiveMode
                        ? const Color(0x33B50000)
                        : const Color(0x1600260F))
                    .withValues(alpha: isLiveMode ? 0.3 : 0.12),
                blurRadius: (isLiveMode ? 18 : 10) * scale,
                offset: Offset(0, 4 * scale),
              ),
            ],
          ),
          child: Icon(Icons.sensors_rounded, color: textColor, size: 18 * scale),
        ),
      ),
    );
  }
}

class DurationLabel extends StatelessWidget {
  const DurationLabel({super.key, required this.elapsed, required this.scale});

  final Duration elapsed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final uiAccent = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.sizeOf(context).width;
    final mainFontSize = ((width * 0.115) * scale).clamp(30.0, 48.0);
    final hasHours = elapsed.inHours > 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14 * scale, 12 * scale, 14 * scale, 10 * scale),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xDD11151D)
            : Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(
          color: uiAccent.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.16,
          ),
          width: 1 * scale,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16 * scale,
                color: uiAccent.withValues(alpha: 0.72),
              ),
              SizedBox(width: 6 * scale),
              Text(
                'Temps d\'écoute',
                style: GoogleFonts.dmSans(
                  color: uiAccent.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                  fontSize: 12 * scale,
                  letterSpacing: 0.2 * scale,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            _formatBadgeDuration(elapsed),
            style: GoogleFonts.russoOne(
              fontSize: mainFontSize,
              letterSpacing: 0.8,
              color: uiAccent,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            hasHours ? 'heures : minutes : secondes' : 'minutes : secondes',
            style: GoogleFonts.dmSans(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBadgeDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final hours = d.inHours;
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

double _mobileScale(double shortestSide) {
  return (shortestSide / 390).clamp(0.84, 1.12).toDouble();
}
