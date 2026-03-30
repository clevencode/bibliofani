import 'package:flutter/material.dart';

/// Sem elemento HTML fora da web.
Future<void> bibleFmWebReloadLiveStream(String baseUrl) async {}

/// Sempre false fora da web (não usado fora do ramo [kIsWeb]).
final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);

/// Fora da web não actualiza.
final bibleFmWebLiveReloading = ValueNotifier<bool>(false);

/// Fora da web não actualiza.
final bibleFmWebLiveEdgeActive = ValueNotifier<bool>(false);

/// Implementação vazia (não web). Ver `web_native_audio_web.dart`.
class WebNativeAudioControls extends StatelessWidget {
  const WebNativeAudioControls({
    super.key,
    required this.streamUrl,
    this.controlsHeight = 44,
  });

  final String streamUrl;
  final double controlsHeight;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
