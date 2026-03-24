import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
      androidNotificationOngoing: true,
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
