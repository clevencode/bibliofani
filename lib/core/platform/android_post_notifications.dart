import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Solicita [POST_NOTIFICATIONS] no Android 13+ para a notificação MediaStyle aparecer.
/// Chamado depois do primeiro frame para o diálogo do sistema ter contexto de actividade.
/// Em versões mais antigas ou noutras plataformas, não faz nada.
Future<void> ensureAndroidPostNotificationsPermission() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited || status.isRestricted) {
      return;
    }
    if (status.isPermanentlyDenied) {
      return;
    }
    await Permission.notification.request();
  } catch (e, stack) {
    debugPrint('ensureAndroidPostNotificationsPermission: $e\n$stack');
  }
}
