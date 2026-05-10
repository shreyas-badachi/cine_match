import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'sync_service.dart';

/// Listens to connectivity transitions and triggers a sync when the device
/// comes online. Lives as long as the [ProviderScope] — disposed automatically
/// on app teardown.
///
/// This is the *foreground* sync trigger. WorkManager handles the case where
/// the app isn't running at all.
class SyncScheduler {
  SyncScheduler({
    required this.connectivity,
    required this.syncService,
  });

  final ConnectivityService connectivity;
  final SyncService syncService;

  StreamSubscription<bool>? _sub;
  bool _wasOnline = false;
  bool _syncInFlight = false;

  void start() {
    _sub = connectivity.watchOnline().listen(_onConnectivityChanged);
  }

  Future<void> _onConnectivityChanged(bool isOnline) async {
    final wasOffline = !_wasOnline;
    _wasOnline = isOnline;

    // Only trigger on offline → online transitions, not on every event.
    if (!isOnline || !wasOffline || _syncInFlight) return;

    _syncInFlight = true;
    try {
      final result = await syncService.syncPendingUsers();
      if (kDebugMode) {
        debugPrint(
          'SyncScheduler: synced ${result.synced}, failed ${result.failed}',
        );
      }
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(
    connectivity: ref.watch(connectivityServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
  scheduler.start();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
