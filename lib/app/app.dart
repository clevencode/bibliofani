import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bibleco/core/theme/app_theme.dart';

class _RadioAppScrollBehavior extends MaterialScrollBehavior {
  const _RadioAppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class RadioApp extends StatelessWidget {
  const RadioApp({
    super.key,
    required this.home,
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bibleco',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'bibleco_app',
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark,
      scrollBehavior: const _RadioAppScrollBehavior(),
      home: home,
    );
  }
}