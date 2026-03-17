import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

const Color _uiAccent = Color(0xFF00260F);
const Color _screenBg = Color(0x80808080);

class RadioPlayerPage extends ConsumerWidget {
  const RadioPlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(radioPlayerProvider);
    final notifier = ref.read(radioPlayerProvider.notifier);
    final isCompact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: _screenBg,
      body: SafeArea(
        child: Container(
          color: _screenBg,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: BibleFmCover(),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: constraints.maxWidth.clamp(280.0, 440.0),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isCompact ? 18 : 26,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _uiAccent.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2200260F),
                              blurRadius: 30,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PlaybackStatusChip(
                              isPlaying: state.isPlaying,
                              isBuffering: state.isBuffering,
                            ),
                            SizedBox(height: isCompact ? 18 : 24),
                            DurationLabel(elapsed: state.elapsed),
                            const SizedBox(height: 8),
                            Text(
                              state.isBuffering
                                  ? 'Conectando ao stream...'
                                  : state.isPlaying
                                      ? 'Transmitindo agora'
                                      : 'Toque em play para ouvir',
                              style: GoogleFonts.dmSans(
                                color: _uiAccent.withValues(alpha: 0.76),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: isCompact ? 20 : 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                LiveIconButton(
                                  isLiveMode: state.isLiveMode,
                                  onLiveTap: notifier.goLive,
                                ),
                                const SizedBox(width: 18),
                                PlayButton(
                                  isPlaying: state.isPlaying,
                                  isLoading: state.isBuffering,
                                  onTap: notifier.togglePlayPause,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        state.errorMessage!,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.redAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: constraints.maxHeight > 760 ? 24 : 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class BibleFmCover extends StatelessWidget {
  const BibleFmCover({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final titleFont = (size.width * 0.1).clamp(30.0, 42.0);
    final iconSize = (size.width * 0.07).clamp(22.0, 30.0);

    return SizedBox(
      width: double.infinity,
      height: 90,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FFCC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _uiAccent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Text(
              'BIBLE FM',
              style: GoogleFonts.russoOne(
                color: _uiAccent,
                fontSize: titleFont,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _uiAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: _uiAccent.withValues(alpha: 0.85),
                size: iconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({
    required this.isPlaying,
    required this.isBuffering,
  });

  final bool isPlaying;
  final bool isBuffering;

  @override
  Widget build(BuildContext context) {
    final isLive = isPlaying && !isBuffering;
    final color = isLive ? const Color(0xFF148A37) : _uiAccent.withValues(alpha: 0.72);
    final label = isBuffering
        ? 'Conectando'
        : isLive
            ? 'Ao vivo'
            : 'Pausado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBuffering ? Icons.sync_rounded : Icons.fiber_manual_record_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.8,
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
  });

  final bool isLiveMode;
  final VoidCallback onLiveTap;

  @override
  Widget build(BuildContext context) {
    final color = isLiveMode ? _uiAccent : _uiAccent.withValues(alpha: 0.7);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onLiveTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isLiveMode
              ? _uiAccent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.72),
          border: Border.all(color: color, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_tethering_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: GoogleFonts.dmSans(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DurationLabel extends StatelessWidget {
  const DurationLabel({super.key, required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = (width * 0.14).clamp(38.0, 56.0);

    return Text(
      _formatBadgeDuration(elapsed),
      style: GoogleFonts.russoOne(
        fontSize: fontSize,
        letterSpacing: 1,
        color: _uiAccent,
      ),
    );
  }
}

String _formatBadgeDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final hours = d.inHours.toString().padLeft(2, '0');
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
