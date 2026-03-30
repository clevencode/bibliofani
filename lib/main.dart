import 'package:flutter/material.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const RadioApp(home: RadioPlayerPage()),
  );
}
