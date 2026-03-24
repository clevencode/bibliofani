import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/core/theme/app_theme_mode_providers.dart';

/// Toggle **claro / escuro** estilo interruptor: trilho + polegar; arrastar
/// interpola o tema em tempo real. Cores vêm do [ColorScheme] actual.
class AppThemeModeToggle extends ConsumerWidget {
  const AppThemeModeToggle({super.key, required this.layoutScale});

  final double layoutScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final blend = ref.watch(themeBlendProvider);
    final dragging = ref.watch(themeDragActiveProvider);
    final lightOn = blend < 0.5;

    final h = AppSpacing.g(6, layoutScale);
    final w = AppSpacing.g(15, layoutScale);
    final iconSize = AppSpacing.g(2, layoutScale);
    final radius = BorderRadius.circular(h / 2);
    final inset = AppSpacing.gHalf(layoutScale);

    Color iconColor(bool selected) {
      return selected
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.42);
    }

    void setLight() {
      ref.read(appThemeModeProvider.notifier).state = ThemeMode.light;
    }

    void setDark() {
      ref.read(appThemeModeProvider.notifier).state = ThemeMode.dark;
    }

    final notifier = ref.read(themeBlendProvider.notifier);

    return Tooltip(
      message: 'Thème',
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final innerW = constraints.maxWidth;
                  final innerH = constraints.maxHeight;
                  final thumbW = innerW / 2;
                  final thumbRadius = BorderRadius.circular(innerH / 2);
                  final thumbLeft = blend * (innerW / 2);

                  return SizedBox(
                    width: innerW,
                    height: innerH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) => notifier.beginDrag(),
                      onHorizontalDragUpdate: (details) {
                        final t =
                            (details.localPosition.dx / innerW).clamp(0.0, 1.0);
                        notifier.updateDrag(t);
                      },
                      onHorizontalDragEnd: (_) => notifier.endDrag(),
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
                            top: 0,
                            width: thumbW,
                            height: innerH,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: thumbRadius,
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(alpha: 0.14),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
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
                                      onTap: setLight,
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
                                      onTap: setDark,
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
