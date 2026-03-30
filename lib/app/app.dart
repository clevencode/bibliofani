import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Raiz da app: tema **escuro fixo**, acessibilidade e estado restaurável (Material 3).
class RadioApp extends StatelessWidget {
  const RadioApp({
    super.key,
    required this.home,
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible FM',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'biblefm_app',
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark,
      home: home,
    );
  }
}