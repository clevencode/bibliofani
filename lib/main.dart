import 'dart:ui' show PlatformDispatcher;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/core/platform/android_ui_task_lifecycle.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Erro assíncrono não apanhado: $error\n$stack');
    }
    return false;
  };

  if (!kIsWeb) {
    installAndroidUiTaskRemovedChannel();
  }

  await _bootstrapAudio();

  runApp(
    const ProviderScope(
      child: RadioApp(),
    ),
  );
}

/// Sessão de áudio + notificação em segundo plano. Falhas não bloqueiam [runApp].
Future<void> _bootstrapAudio() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'main',
        context: ErrorDescription('Falha ao configurar AudioSession'),
      ),
    );
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: kAndroidRadioNotificationChannelId,
      androidNotificationChannelName: kAndroidRadioNotificationChannelName,
      androidNotificationChannelDescription:
          'Reprodução da Bible FM com controlos na notificação.',
      androidNotificationOngoing: true,
      // Em pausa, retira o serviço em primeiro plano (melhor para bateria e políticas Android).
      androidStopForegroundOnPause: true,
      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
    );
  } catch (e, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'main',
        context: ErrorDescription('Falha ao inicializar JustAudioBackground'),
      ),
    );
  }
}
