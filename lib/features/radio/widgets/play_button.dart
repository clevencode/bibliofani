import 'package:flutter/material.dart';

/// Botao principal de reproducao sem container.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.size = 96,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;
  final double size;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playAccent = Theme.of(context).colorScheme.primary;
    // Trocamos entre play e pause sem animacoes de pulso.
    final iconData =
        widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final buttonSize = widget.size.clamp(74.0, 116.0);
    final progressSize = (buttonSize * 0.33).clamp(24.0, 34.0);
    final iconSize = (buttonSize * 0.44).clamp(34.0, 48.0);
    final fillColor =
        isDark ? const Color(0xE6131620) : Colors.white.withValues(alpha: 0.98);
    final borderColor = playAccent.withValues(alpha: isDark ? 0.32 : 0.2);

    return Semantics(
      button: true,
      label: widget.isLoading
          ? 'Chargement'
          : widget.isPlaying
              ? 'Mettre en pause la diffusion'
              : 'Reprendre la diffusion',
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonSize),
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(color: borderColor, width: 1.25),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black87).withValues(
                  alpha: isDark ? 0.2 : 0.1,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: progressSize,
                    height: progressSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: playAccent,
                    ),
                  )
                : Icon(iconData, size: iconSize, color: playAccent),
          ),
        ),
      ),
    );
  }
}
