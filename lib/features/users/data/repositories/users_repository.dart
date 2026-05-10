import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/users_dao.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/workmanager_callback.dart';
import '../datasources/users_remote_datasource.dart';
import '../models/reqres_user.dart';

/// Orchestrates the local DB and the Reqres API for user data.
///
/// Write paths follow a "local-first, sync-best-effort" rule:
/// 1. Always write to the local DB synchronously so the UI updates immediately.
/// 2. If online, fire an immediate POST attempt and update `serverId` on success.
/// 3. If offline (or the immediate attempt fails), the row stays
///    `pendingSync = true` for the SyncService / WorkManager to pick up later.
///
/// The user never has to wait for the network. The Users page shows the new
/// user as soon as `createUser` returns its local ID.
class UsersRepository {
  UsersRepository({
    required this.usersDao,
    required this.remote,
    required this.connectivity,
  });

  final UsersDao usersDao;
  final UsersRemoteDataSource remote;
  final ConnectivityService connectivity;

  Stream<List<UserWithSavedCount>> watchAll() =>
      usersDao.watchAllWithSavedCount();

  /// Fetches one Reqres page and upserts every user into the local cache.
  /// Returns the API page metadata so the caller can decide whether more
  /// pages exist. The list itself is read from the DB Stream — this method
  /// only populates the cache.
  Future<ReqresUserPage> fetchPage(int page) async {
    final apiPage = await remote.fetchUsers(page: page);
    for (final apiUser in apiPage.users) {
      await _upsertFromApi(apiUser);
    }
    return apiPage;
  }

  Future<void> _upsertFromApi(ReqresUser apiUser) async {
    final existing = await usersDao.getByServerId(apiUser.id);
    if (existing != null) {
      await usersDao.updateProfile(
        localId: existing.id,
        firstName: apiUser.firstName,
        lastName: apiUser.lastName,
        email: apiUser.email,
        avatarUrl: apiUser.avatar,
      );
    } else {
      await usersDao.insertUser(
        UsersCompanion.insert(
          serverId: Value(apiUser.id),
          firstName: apiUser.firstName,
          lastName: apiUser.lastName,
          email: Value(apiUser.email),
          avatarUrl: Value(apiUser.avatar),
          pendingSync: const Value(false),
        ),
      );
    }
  }

  Future<int> createUser({
    required String firstName,
    required String lastName,
    String? movieTaste,
  }) async {
    final localId = await usersDao.insertUser(
      UsersCompanion.insert(
        firstName: firstName,
        lastName: lastName,
        movieTaste: Value(movieTaste),
        pendingSync: const Value(true),
      ),
    );

    final online = await connectivity.isOnline;
    if (online) {
      // Try the optimistic POST in the background. If it succeeds, great —
      // the user is fully synced before they ever finish typing the next one.
      // If it fails, the row stays pending and SyncService handles it.
      unawaited(_optimisticSync(
        localId: localId,
        firstName: firstName,
        lastName: lastName,
        movieTaste: movieTaste,
      ));
    } else {
      // Schedule a WorkManager job that will fire once the OS detects
      // connectivity. Belt-and-braces with SyncScheduler in case the app
      // is killed before connectivity returns.
      unawaited(scheduleSyncOnConnectivity());
    }

    return localId;
  }

  Future<void> _optimisticSync({
    required int localId,
    required String firstName,
    required String lastName,
    String? movieTaste,
  }) async {
    try {
      final fullName = '$firstName $lastName'.trim();
      final serverId = await remote.createUser(
        name: fullName,
        job: movieTaste ?? '',
      );
      await usersDao.markSynced(localId: localId, serverId: serverId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Optimistic sync for user $localId failed: $e');
      }
      // Row stays pending — fine, sync will retry.
    }
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(
    usersDao: ref.watch(usersDaoProvider),
    remote: ref.watch(usersRemoteDataSourceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});
