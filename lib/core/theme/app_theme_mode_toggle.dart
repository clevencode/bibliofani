import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/core/theme/app_theme_mode_providers.dart';

/// Toggle **claro / escuro** estilo interruptor: arrastar interpola o tema;
/// **toque** anima o blend (não salta). Flings rápidos escolhem o lado.
class AppThemeModeToggle extends ConsumerStatefulWidget {
  const AppThemeModeToggle({super.key, required this.layoutScale});

  final double layoutScale;

  @override
  ConsumerState<AppThemeModeToggle> createState() => _AppThemeModeToggleState();
}

class _AppThemeModeToggleState extends ConsumerState<AppThemeModeToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapAnim;
  double? _tapFrom;
  double? _tapTo;

  /// Evita que o `.then` de uma animação cancelada aplique o modo errado.
  int _tapSeq = 0;

  @override
  void initState() {
    super.initState();
    _tapAnim = AnimationController(
      vsync: this,
      duration: AppTheme.themeCrossfadeDuration,
    );
    _tapAnim.addListener(_onTapAnimTick);
  }

  @override
  void dispose() {
    _tapAnim.removeListener(_onTapAnimTick);
    _tapAnim.dispose();
    super.dispose();
  }

  void _onTapAnimTick() {
    final from = _tapFrom;
    final to = _tapTo;
    if (from == null || to == null || !mounted) return;
    final u = AppTheme.themeCrossfadeCurve.transform(_tapAnim.value);
    ref.read(themeBlendProvider.notifier).updateDrag(from + (to - from) * u);
  }

  void _cancelTapAnimation() {
    _tapSeq++;
    _tapTo = null;
    _tapFrom = null;
    if (_tapAnim.isAnimating) {
      _tapAnim.stop();
    }
  }

  void _animateBlendOnTap(double target) {
    final current = ref.read(themeBlendProvider);
    if ((current - target).abs() < 0.02) {
      ref.read(appThemeModeProvider.notifier).state = target < 0.5
          ? ThemeMode.light
          : ThemeMode.dark;
      HapticFeedback.selectionClick();
      return;
    }

    ref.read(themeDragActiveProvider.notifier).state = true;
    _tapAnim.stop();
    _tapSeq++;
    final seq = _tapSeq;
    _tapFrom = current;
    _tapTo = target;
    _tapAnim.forward(from: 0).then((_) {
      if (!mounted || seq != _tapSeq || _tapTo == null) return;
      final t = _tapTo!;
      _tapTo = null;
      _tapFrom = null;
      ref.read(themeBlendProvider.notifier).updateDrag(t);
      ref.read(appThemeModeProvider.notifier).state = t < 0.5
          ? ThemeMode.light
          : ThemeMode.dark;
      ref.read(themeDragActiveProvider.notifier).state = false;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blend = ref.watch(themeBlendProvider);
    final dragging = ref.watch(themeDragActiveProvider);
    final lightOn = blend < 0.5;
    final notifier = ref.read(themeBlendProvider.notifier);

    final s = widget.layoutScale;
    final h = AppSpacing.g(5, s);
    final w = AppSpacing.g(13, s);
    final iconSize = AppSpacing.g(2, s) * 0.9;
    final radius = BorderRadius.circular(h / 2);
    final inset = AppSpacing.gHalf(s);
    final thumbPadH = AppSpacing.gHalf(s) * 0.55;
    final thumbPadV = AppSpacing.gHalf(s) * 0.5;

    Color iconColor(bool selected) {
      return selected ? scheme.onSurface : scheme.onSurfaceVariant;
    }

    // Mesma lógica claro/escuro: trilho + polegar com contorno, plano (sem sombra).
    final trackFill = scheme.surfaceContainerLow;
    final trackBorder = scheme.outline.withValues(alpha: 0.52);
    final thumbFill = scheme.surfaceContainerHigh;
    final thumbBorder = scheme.outline.withValues(alpha: 0.48);

    return Tooltip(
      message: 'Thème',
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: trackBorder),
            color: trackFill,
            boxShadow: const [],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final innerW = constraints.maxWidth;
                  final innerH = constraints.maxHeight;
                  final thumbW = (innerW / 2) - (thumbPadH * 2);
                  final thumbH = innerH - (thumbPadV * 2);
                  final thumbTravel = innerW / 2;
                  final thumbLeft = thumbPadH + blend * thumbTravel;
                  final thumbRadius = BorderRadius.circular(
                    (thumbH / 2).clamp(4.0, 999),
                  );

                  return SizedBox(
                    width: innerW,
                    height: innerH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        _cancelTapAnimation();
                        notifier.beginDrag();
                      },
                      onHorizontalDragUpdate: (details) {
                        final t = (details.localPosition.dx / innerW).clamp(
                          0.0,
                          1.0,
                        );
                        notifier.updateDrag(t);
                      },
                      onHorizontalDragEnd: (details) {
                        notifier.endDrag(
                          horizontalVelocityPx:
                              details.velocity.pixelsPerSecond.dx,
                        );
                        HapticFeedback.selectionClick();
                      },
                      onHorizontalDragCancel: () => notifier.endDrag(),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          AnimatedPositioned(
                            duration: dragging
                                ? Duration.zero
                                : AppTheme.themeCrossfadeDuration,
                            curve: AppTheme.themeCrossfadeCurve,
                            left: thumbLeft,
                            top: thumbPadV,
                            width: thumbW,
                            height: thumbH,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: thumbFill,
                                borderRadius: thumbRadius,
                                border: Border.all(
                                  color: thumbBorder,
                                  width: 1,
                                ),
                                boxShadow: const [],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: lightOn,
                                  label: 'Thème clair',
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _animateBlendOnTap(0),
                                      child: Center(
                                        child: Icon(
                                          Icons.light_mode_rounded,
                                          size: iconSize,
                                          color: iconColor(lightOn),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: !lightOn,
                                  label: 'Thème sombre',
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _animateBlendOnTap(1),
                                      child: Center(
                                        child: Icon(
                                          Icons.dark_mode_rounded,
                                          size: iconSize,
                                          color: iconColor(!lightOn),
                                        ),
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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
