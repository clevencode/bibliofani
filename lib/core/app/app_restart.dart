import 'package:flutter/foundation.dart';
import 'package:restart_app/restart_app.dart';

/// Recarrega o processo da app (nativo). No Android usa [forceKill] para evitar
/// bloqueios de recursos após falhas de rede / áudio.
Future<void> restartApplication() async {
  final useForceKill =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  try {
    final ok = await Restart.restartApp(forceKill: useForceKill);
    if (kDebugMode && !ok) {
      debugPrint('restartApplication: Restart.restartApp devolveu false');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('restartApplication: $e\n$st');
    }
  }
}
