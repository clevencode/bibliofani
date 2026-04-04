import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:bibleco/features/radio/screens/radio_player_page.dart'
    deferred as radio;

const Color _kLoaderBackground = Color(0xFF000000);
const Color _kLoaderErrorFg = Color(0xFFE4E4E7);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleMicrotask(() {
        radio.loadLibrary().then((_) {
          if (mounted) setState(() => _ready = true);
        }).catchError((Object e, StackTrace _) {
          if (mounted) setState(() => _error = e);
        });
      });
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
      return const ColoredBox(
        color: Color(0x00000000),
        child: SizedBox.expand(),
      );
    }
    return radio.RadioPlayerPage();
  }
}
