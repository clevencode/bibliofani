import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Garante [POST_NOTIFICATIONS] no Android 13+ (API 33+), **necessário** para a
/// notificação MediaStyle / FGS aparecer de forma fiável.
///
/// Devolve `true` se as notificações estão permitidas (ou se a plataforma não exige
/// pedido em tempo de execução). **Await** antes de [AudioPlayer.play] na primeira
/// leitura ou após o utilizador revogar a permissão.
Future<bool> ensureAndroidPostNotificationsPermission() async {
  if (kIsWeb) return true;
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    var status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isRestricted) return false;
    if (status.isPermanentlyDenied) return false;
    status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  } catch (e, stack) {
    debugPrint('ensureAndroidPostNotificationsPermission: $e\n$stack');
    return false;
  }
}
