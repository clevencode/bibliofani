import 'package:flutter/widgets.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/radio_home_impl.dart'
    if (dart.library.html) 'package:meu_app/radio_home_html.dart'
    if (dart.library.io) 'package:meu_app/radio_home_io.dart' as radio_home;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RadioApp(home: radio_home.createRadioHome()));
}
