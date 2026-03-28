import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meu_app/core/branding/app_assets.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Splash Flutter alinhada à splash nativa (#171717 + logo).
///
/// [precacheImage] reduz jank quando a imagem aparece no primeiro frame útil.
class OpeningSplashScreen extends StatefulWidget {
  const OpeningSplashScreen({super.key});

  @override
  State<OpeningSplashScreen> createState() => _OpeningSplashScreenState();
}

class _OpeningSplashScreenState extends State<OpeningSplashScreen> {
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    unawaited(precacheImage(const AssetImage(kAppLogoAsset), context));
  }

  @override
  Widget build(BuildContext context) {
    return const _OpeningSplashView();
  }
}

class _OpeningSplashView extends StatelessWidget {
  const _OpeningSplashView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.darkAppBackground,
      child: SafeArea(
        child: Center(
          child: Semantics(
            label: 'Bible FM',
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.biggest.shortestSide;
                  final logoSize = (side * 0.28).clamp(120.0, 200.0);
                  return Image.asset(
                    kAppLogoAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.high,
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
