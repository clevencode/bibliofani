import 'package:flutter/cupertino.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart'
    deferred as radio;

// Mesmas cores que [AppTheme.darkAppBackground] / boot HTML — evita importar Material/AppTheme neste módulo.
const Color _kLoaderBackground = Color(0xFF09090B);
const Color _kLoaderErrorFg = Color(0xFFE4E4E7);

/// Web: o leitor corre num **módulo diferido** para menos parse/CPU no arranque
/// (boas práticas Flutter web — [deferred imports](https://dart.dev/guides/language/language-tour#lazily-loading-a-library)).
Widget createRadioHome() => const _DeferredRadioHost();

class _DeferredRadioHost extends StatefulWidget {
  const _DeferredRadioHost();

  @override
  State<_DeferredRadioHost> createState() => _DeferredRadioHostState();
}

class _DeferredRadioHostState extends State<_DeferredRadioHost> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    radio.loadLibrary().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object e, StackTrace st) {
      debugPrint('radio_home_html: loadLibrary failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const ColoredBox(
        color: _kLoaderBackground,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Impossible de charger le lecteur.\nActualisez la page.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kLoaderErrorFg,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return ColoredBox(
        color: _kLoaderBackground,
        child: Center(
          child: Semantics(
            label: 'Chargement du lecteur',
            child: CupertinoActivityIndicator(radius: 14),
          ),
        ),
      );
    }
    return radio.RadioPlayerPage();
  }
}
