import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/core/audio/audio_runtime_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final notificationColor = _resolveNotificationColor();

  try {
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.music());

    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.exemplo.meu_app.radio',
      androidNotificationChannelName: 'Lecture Bible FM',
      androidNotificationChannelDescription: 'Diffusion en direct de Bible FM',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_stat_audio',
      notificationColor: notificationColor,
    );
    AudioRuntimeConfig.backgroundEnabled = true;
  } catch (e, st) {
    AudioRuntimeConfig.backgroundEnabled = false;
    debugPrint('Falha ao iniciar media session/notificacao: $e');
    debugPrint(st.toString());
  }

  runApp(
    const ProviderScope(
      child: RadioApp(),
    ),
  );
}

Color _resolveNotificationColor() {
  final isDark =
      SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  return isDark ? const Color(0xFF1A2517) : const Color(0xFFF8FFE5);
}
