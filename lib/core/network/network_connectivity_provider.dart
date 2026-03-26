import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tipo de ligação de rede (mais fino que só offline/online).
enum RadioNetworkLink {
  /// Ainda não houve leitura da plataforma.
  unknown,

  /// Sem interface de dados.
  offline,

  /// Wi‑Fi activo.
  wifi,

  /// Dados móveis.
  cellular,

  /// Cabo / adaptador Ethernet.
  ethernet,

  /// VPN (sobre outra interface).
  vpn,

  /// Bluetooth, `other`, etc.
  other,
}

extension RadioNetworkLinkX on RadioNetworkLink {
  bool get isOffline => this == RadioNetworkLink.offline;

  /// Indicador discreto sob o cabeçalho (Wi‑Fi, dados móveis, …).
  bool get showsTransportHint =>
      this != RadioNetworkLink.unknown &&
      this != RadioNetworkLink.offline;
}

/// Estado bruto da conectividade; use [networkOfflineProvider] para só offline.
final networkLinkProvider =
    StateNotifierProvider<NetworkConnectivityNotifier, RadioNetworkLink>((ref) {
  return NetworkConnectivityNotifier();
});

/// Compatível com código que só precisa de `bool` offline.
final networkOfflineProvider = Provider<bool>((ref) {
  return ref.watch(networkLinkProvider).isOffline;
});

class NetworkConnectivityNotifier extends StateNotifier<RadioNetworkLink> {
  NetworkConnectivityNotifier() : super(RadioNetworkLink.unknown) {
    _connectivity = Connectivity();
    initialConnectivityFuture = _bootstrap();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('networkLinkProvider stream: $e\n$st');
        }
      },
    );
  }

  late final Connectivity _connectivity;
  late final Future<void> initialConnectivityFuture;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Primeira leitura da plataforma; útil antes do arranque automático do leitor.
  Future<void> _bootstrap() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      // Mantém o último estado se a verificação inicial falhar.
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final link = _linkFromResults(results);
    if (state != link) {
      state = link;
    }
  }

  static RadioNetworkLink _linkFromResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return RadioNetworkLink.offline;
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return RadioNetworkLink.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return RadioNetworkLink.cellular;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return RadioNetworkLink.ethernet;
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return RadioNetworkLink.vpn;
    }
    if (results.contains(ConnectivityResult.bluetooth)) {
      return RadioNetworkLink.other;
    }
    if (results.contains(ConnectivityResult.other)) {
      return RadioNetworkLink.other;
    }
    return RadioNetworkLink.other;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
