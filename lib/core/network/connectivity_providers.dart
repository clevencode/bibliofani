import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Último estado conhecido das interfaces (Wi‑Fi, dados móveis, etc.).
///
/// Não garante que exista Internet (ex.: Wi‑Fi sem rota), mas cobre o caso mais
/// comum de “sem rede” para a UI e para evitar pedidos inúteis ao stream.
final connectivityResultsProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  if (kIsWeb) {
    yield const [ConnectivityResult.other];
    return;
  }
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// Se existe pelo menos uma interface que não seja [ConnectivityResult.none].
final hasNetworkProvider = Provider<bool>((ref) {
  if (kIsWeb) return true;
  return ref.watch(connectivityResultsProvider).maybeWhen(
        data: networkResultsAllowPlayback,
        orElse: () => true,
      );
});

bool networkResultsAllowPlayback(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}
