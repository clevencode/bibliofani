import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/core/theme/app_theme_mode_providers.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';

/// Raiz da app: tema, acessibilidade (escala de texto limitada), system UI e
/// [restorationScopeId] para estado restaurável (Material 3).
class RadioApp extends ConsumerWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blend = ref.watch(themeBlendProvider);
    final dragging = ref.watch(themeDragActiveProvider);
    final lerped = ThemeData.lerp(
      AppTheme.light,
      AppTheme.dark,
      blend.clamp(0.0, 1.0),
    );
    return MaterialApp(
      title: 'Radio Bible FM',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'biblefm_app',
      themeMode: ref.watch(appThemeModeProvider),
      themeAnimationDuration:
          dragging ? Duration.zero : AppTheme.themeCrossfadeDuration,
      themeAnimationCurve: AppTheme.themeCrossfadeCurve,
      theme: lerped,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('fr', 'FR'),
        Locale('en'),
        Locale('pt'),
        Locale('pt', 'BR'),
      ],
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        );
        final content = AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
        // Limita o factor de escala do sistema para evitar ruturas de layout
        // (acessibilidade + layouts densos).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: content,
        );
      },
      home: const RadioPlayerPage(),
    );
  }
}
