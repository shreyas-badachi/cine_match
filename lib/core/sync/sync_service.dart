import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/users/data/datasources/users_remote_datasource.dart';
import '../database/daos/users_dao.dart';
import '../database/database_provider.dart';

class SyncResult {
  const SyncResult({required this.synced, required this.failed});

  final int synced;
  final int failed;

  bool get isComplete => failed == 0;

  static const empty = SyncResult(synced: 0, failed: 0);
}

/// Picks up users that were created offline (`pendingSync = true`),
/// POSTs them to Reqres one by one, and updates each with the server-assigned
/// ID via `UsersDao.markSynced`. Designed to be safe to call repeatedly:
/// already-synced users won't be picked up; failed users stay pending so
/// the next run retries.
class SyncService {
  SyncService({
    required this.usersDao,
    required this.remote,
  });

  final UsersDao usersDao;
  final UsersRemoteDataSource remote;

  Future<SyncResult> syncPendingUsers() async {
    final pending = await usersDao.getPendingSync();
    if (pending.isEmpty) return SyncResult.empty;

    var synced = 0;
    var failed = 0;

    for (final user in pending) {
      try {
        final fullName = '${user.firstName} ${user.lastName}'.trim();
        final serverId = await remote.createUser(
          name: fullName,
          job: user.movieTaste ?? '',
        );
        await usersDao.markSynced(localId: user.id, serverId: serverId);
        synced++;
      } catch (_) {
        // Network failure or 4xx — leave the row pending. The retry
        // interceptor already handled transient errors; anything reaching
        // here is either a hard failure or all retries were exhausted.
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    usersDao: ref.watch(usersDaoProvider),
    remote: ref.watch(usersRemoteDataSourceProvider),
  );
});
