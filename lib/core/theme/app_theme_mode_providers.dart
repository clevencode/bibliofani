import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo persistido (claro / escuro / sistema). O aspeto visual em tempo real
/// vem de [themeBlendProvider] (interpolação 0→1).
final appThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.light,
);

/// True enquanto o utilizador arrasta o toggle de tema (sem animação interna
/// do [MaterialApp] entre frames).
final themeDragActiveProvider = StateProvider<bool>((ref) => false);

double _blendForMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 0;
    case ThemeMode.dark:
      return 1;
    case ThemeMode.system:
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? 1
          : 0;
  }
}

/// Interpolação 0 = tema claro, 1 = tema escuro. Durante o arrasto actualiza-se
/// em tempo real; ao largar faz-se snap e [appThemeModeProvider] alinha-se.
class ThemeBlendNotifier extends StateNotifier<double> {
  ThemeBlendNotifier(this.ref) : super(_initialBlend(ref)) {
    ref.listen<ThemeMode>(appThemeModeProvider, (prev, next) {
      if (!ref.read(themeDragActiveProvider)) {
        state = _blendForMode(next);
      }
    });
  }

  final Ref ref;

  static double _initialBlend(Ref ref) {
    return _blendForMode(ref.read(appThemeModeProvider));
  }

  void beginDrag() {
    ref.read(themeDragActiveProvider.notifier).state = true;
  }

  void updateDrag(double t) {
    state = t.clamp(0.0, 1.0);
  }

  void endDrag() {
    final snap = state < 0.5 ? 0.0 : 1.0;
    state = snap;
    ref.read(appThemeModeProvider.notifier).state =
        snap == 0 ? ThemeMode.light : ThemeMode.dark;
    ref.read(themeDragActiveProvider.notifier).state = false;
  }
}

final themeBlendProvider =
    StateNotifierProvider<ThemeBlendNotifier, double>((ref) {
  return ThemeBlendNotifier(ref);
});
