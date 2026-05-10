import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkStatus {
  const NetworkStatus({this.isReconnecting = false, this.attempt = 0});
  final bool isReconnecting;
  final int attempt;

  static const idle = NetworkStatus();
}

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  NetworkStatusNotifier() : super(NetworkStatus.idle);

  void startRetry(int attempt) =>
      state = NetworkStatus(isReconnecting: true, attempt: attempt);

  void clear() => state = NetworkStatus.idle;
}

final networkStatusProvider =
    StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>(
  (_) => NetworkStatusNotifier(),
);
