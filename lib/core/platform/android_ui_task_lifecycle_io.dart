import 'dart:io' show Platform;

import 'package:flutter/services.dart';

const _channel = MethodChannel('biblefm.android_lifecycle');

void Function()? _onUiTaskFinishing;

/// Escuta [MainActivity] quando a tarefa é removida das recentes (ou back fecha a UI).
void installAndroidUiTaskRemovedChannel() {
  if (!Platform.isAndroid) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'uiTaskFinishing') {
      _onUiTaskFinishing?.call();
    }
  });
}

/// O [RadioPlayerUiNotifier] regista aqui para parar o áudio alinhado ao fecho da tarefa.
void registerAndroidUiTaskRemovedCallback(void Function()? onUiTaskFinishing) {
  if (!Platform.isAndroid) return;
  _onUiTaskFinishing = onUiTaskFinishing;
}
