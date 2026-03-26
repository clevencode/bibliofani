import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart'
    show
        kAndroidMediaSeekSkipInterval,
        kAndroidRadioNotificationChannelDescription,
        kAndroidRadioNotificationChannelId,
        kAndroidRadioNotificationChannelName,
        kAndroidMediaNotificationIcon;

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
///
/// **Interrupções (chamada, etc.):** [AudioSessionConfiguration.music] + foco Android;
/// [RadioPlayerUiNotifier] escuta [AudioSession.interruptionEventStream] para pausar/retomar a UI.
///
/// **Android (2024–2026):** o serviço usa `foregroundServiceType="mediaPlayback"` no manifest;
/// em API 33+, [ensureAndroidPostNotificationsPermission] pede `POST_NOTIFICATIONS` após o 1.º frame.
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
          kAndroidRadioNotificationChannelDescription,
      notificationColor: AppTheme.mediaNotificationBackground,
      androidNotificationIcon: kAndroidMediaNotificationIcon,
      androidNotificationOngoing: true,
      androidResumeOnClick: true,
      androidNotificationClickStartsActivity: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: false,
      preloadArtwork: false,
      fastForwardInterval: kAndroidMediaSeekSkipInterval,
      rewindInterval: kAndroidMediaSeekSkipInterval,
      androidBrowsableRootExtras: const <String, dynamic>{
        'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
        'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
      },
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
