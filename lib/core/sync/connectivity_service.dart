import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  /// Emits `true` when at least one transport (wifi/mobile/ethernet/vpn) is up.
  /// `distinct()` collapses bursts of identical events.
  Stream<bool> watchOnline() {
    return _connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}

final connectivityProvider = Provider<Connectivity>((_) => Connectivity());

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref.watch(connectivityProvider));
});
