import 'package:flutter/widgets.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart'
    deferred as radio;

// Erro: mesmo fundo que [index.html] — evita importar Material/AppTheme.
const Color _kLoaderBackground = Color(0xFF000000);
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
    }).catchError((Object e, StackTrace _) {
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
    // Sem segundo ecrã nem spinner: o splash HTML (#flutter-boot) cobre o arranque até ao primeiro frame.
    if (!_ready) {
      return const ColoredBox(
        color: Color(0x00000000),
        child: SizedBox.expand(),
      );
    }
    return radio.RadioPlayerPage();
  }
}
