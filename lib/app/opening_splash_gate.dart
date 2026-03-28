import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:meu_app/app/opening_splash_screen.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';

/// Orquestra o arranque: splash nativa → [OpeningSplashScreen] → leitor.
///
/// Chama [FlutterNativeSplash.remove] no [initState] (síncrono), como no guia do
/// pacote, para libertar o 1.º frame depois de [preserve] no `main`.
class OpeningSplashGate extends StatefulWidget {
  const OpeningSplashGate({
    super.key,
    required this.initFuture,
  });

  final Future<void> initFuture;

  @override
  State<OpeningSplashGate> createState() => _OpeningSplashGateState();
}

class _OpeningSplashGateState extends State<OpeningSplashGate> {
  bool _nativeSplashRemoved = false;

  @override
  void initState() {
    super.initState();
    // Não usar apenas postFrame: com [deferFirstFrame] activo, o 1.º frame pode
    // ficar em espera até [remove] — remove síncrono é o padrão do pacote.
    if (!_nativeSplashRemoved) {
      _nativeSplashRemoved = true;
      FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: widget.initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: snapshot.error!,
                stack: snapshot.stackTrace,
                library: 'opening_splash_gate',
                context: ErrorDescription(
                  'Arranque: o leitor abre na mesma; áudio pode precisar de retry.',
                ),
              ),
            );
          }
          return const RadioPlayerPage();
        }
        return const OpeningSplashScreen();
      },
    );
  }
}
