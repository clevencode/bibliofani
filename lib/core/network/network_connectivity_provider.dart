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
  /// Re-tenta com pequenos atrasos se [checkConnectivity] falhar (evita ficar em [unknown]).
  Future<void> _bootstrap() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        _apply(await _connectivity.checkConnectivity());
        return;
      } catch (_) {
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }
  }

  /// Se, após [initialConnectivityFuture], o estado ainda for [unknown], volta a consultar a API.
  Future<void> ensureKnownLink() async {
    await initialConnectivityFuture;
    for (var i = 0; i < 4 && state == RadioNetworkLink.unknown; i++) {
      await Future<void>.delayed(Duration(milliseconds: 100 * (i + 1)));
      try {
        _apply(await _connectivity.checkConnectivity());
      } catch (_) {}
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
