import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/app/opening_splash_gate.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart'
    show
        kAndroidMediaSeekSkipInterval,
        kAndroidRadioNotificationChannelDescription,
        kAndroidRadioNotificationChannelId,
        kAndroidRadioNotificationChannelName,
        kAndroidMediaNotificationIcon;

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Mantém a splash nativa (mesmo fundo/logo) até o Flutter poder pintar o ecrã
  // equivalente — evita flash branco e duplo salto visual.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final bootstrapFuture = _bootstrapAudio();
  final openingFuture = Future.wait<void>(<Future<void>>[
    bootstrapFuture,
    Future<void>.delayed(const Duration(milliseconds: 280)),
  ]);

  runApp(
    ProviderScope(
      child: RadioApp(
        home: OpeningSplashGate(initFuture: openingFuture),
      ),
    ),
  );
}

/// Sessão de áudio + notificação em segundo plano. Falhas não bloqueiam [runApp].
///
/// **Interrupções (chamada, etc.):** [AudioSessionConfiguration.music] + foco Android;
/// [RadioPlayerUiNotifier] escuta [AudioSession.interruptionEventStream] para pausar/retomar a UI.
///
/// **Android:** `foregroundServiceType="mediaPlayback"` + `POST_NOTIFICATIONS` (API 33+).
/// [androidStopForegroundOnPause] a `false` mantém o FGS visível em pausa (rádio — evita
/// cortes agressivos em alguns OEMs e mantém a notificação utilizável).
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
      // Leitura activa: o SO trata como sessão contínua (menos swipe acidental).
      androidNotificationOngoing: true,
      androidResumeOnClick: true,
      androidNotificationClickStartsActivity: true,
      // Rádio: manter notificação / FGS em pausa para segundo plano e controlos fiáveis.
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: false,
      preloadArtwork: false,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      // O stream é em directo (sem seek na UI); estes intervalos satisfazem a API
      // audio_service / comandos remotos sem serem expostos como controlos úteis.
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
