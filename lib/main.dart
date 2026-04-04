import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:bibleco/app/app.dart';
import 'package:bibleco/radio_home_impl.dart'
    if (dart.library.html) 'package:bibleco/radio_home_html.dart'
    if (dart.library.io) 'package:bibleco/radio_home_io.dart' as radio_home;

void _configureSilentFlutterConsoleOnWebRelease() {
  if (!kIsWeb || !kReleaseMode) return;
  FlutterError.onError = (_) {};
  PlatformDispatcher.instance.onError = (_, _) => true;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureSilentFlutterConsoleOnWebRelease();
  runApp(RadioApp(home: radio_home.createRadioHome()));
}
