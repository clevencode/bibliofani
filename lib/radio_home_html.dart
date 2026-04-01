import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart'
    deferred as radio;

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
      return Scaffold(
        backgroundColor: AppTheme.darkAppBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger le lecteur.\nActualisez la page.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return Scaffold(
        backgroundColor: AppTheme.darkAppBackground,
        body: Center(
          child: Semantics(
            label: 'Chargement du lecteur',
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }
    return radio.RadioPlayerPage();
  }
}
