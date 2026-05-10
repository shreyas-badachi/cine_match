import 'package:cine_match/core/database/app_database.dart';
import 'package:cine_match/core/sync/sync_service.dart';
import 'package:cine_match/features/users/data/datasources/users_remote_datasource.dart';
import 'package:cine_match/features/users/data/models/reqres_user.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-rolled fake — records calls and returns scripted server IDs.
/// Hand-rolled instead of mocktail to avoid an extra dev dependency for one test.
class _FakeRemote implements UsersRemoteDataSource {
  _FakeRemote({this.scriptedIds = const [], this.failOnCalls = const {}});

  final List<int> scriptedIds;
  final Set<int> failOnCalls;

  int callCount = 0;
  final List<({String name, String job})> requests = [];

  @override
  Future<int> createUser({required String name, required String job}) async {
    final i = callCount++;
    requests.add((name: name, job: job));
    if (failOnCalls.contains(i)) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: 'users'),
        reason: 'Simulated failure',
      );
    }
    return scriptedIds[i];
  }

  @override
  Future<ReqresUserPage> fetchUsers({required int page}) async {
    throw UnimplementedError('not used in this test');
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertOfflineUser({
    required String firstName,
    required String lastName,
    String? movieTaste,
  }) {
    return db.usersDao.insertUser(
      UsersCompanion.insert(
        firstName: firstName,
        lastName: lastName,
        movieTaste: Value(movieTaste),
        pendingSync: const Value(true),
      ),
    );
  }

  test('syncs every pending user, marks each with its server id', () async {
    final l1 = await insertOfflineUser(firstName: 'Alex', lastName: 'Doe', movieTaste: 'horror');
    final l2 = await insertOfflineUser(firstName: 'Beth', lastName: 'Smith');

    final remote = _FakeRemote(scriptedIds: [101, 202]);
    final service = SyncService(usersDao: db.usersDao, remote: remote);

    final result = await service.syncPendingUsers();

    expect(result.synced, 2);
    expect(result.failed, 0);
    expect(remote.callCount, 2);
    expect(remote.requests[0].name, 'Alex Doe');
    expect(remote.requests[0].job, 'horror');
    expect(remote.requests[1].name, 'Beth Smith');
    expect(remote.requests[1].job, '');

    final synced1 = await db.usersDao.getById(l1);
    final synced2 = await db.usersDao.getById(l2);
    expect(synced1!.serverId, 101);
    expect(synced1.pendingSync, isFalse);
    expect(synced2!.serverId, 202);
    expect(synced2.pendingSync, isFalse);

    expect(await db.usersDao.getPendingSync(), isEmpty);
  });

  test('partial failure leaves the failing user pending; others sync', () async {
    await insertOfflineUser(firstName: 'A', lastName: 'A');
    final l2 = await insertOfflineUser(firstName: 'B', lastName: 'B');
    await insertOfflineUser(firstName: 'C', lastName: 'C');

    final remote = _FakeRemote(scriptedIds: [10, 0, 30], failOnCalls: {1});
    final service = SyncService(usersDao: db.usersDao, remote: remote);

    final result = await service.syncPendingUsers();

    expect(result.synced, 2);
    expect(result.failed, 1);

    final pending = await db.usersDao.getPendingSync();
    expect(pending, hasLength(1));
    expect(pending.first.id, l2);
    expect(pending.first.firstName, 'B');
  });

  test('idempotent: a second sync run only POSTs the still-pending users', () async {
    await insertOfflineUser(firstName: 'A', lastName: 'A');
    final l2 = await insertOfflineUser(firstName: 'B', lastName: 'B');

    final remote = _FakeRemote(
      scriptedIds: [10, 0, 22],
      failOnCalls: {1},
    );
    final service = SyncService(usersDao: db.usersDao, remote: remote);

    final firstRun = await service.syncPendingUsers();
    expect(firstRun.synced, 1);
    expect(firstRun.failed, 1);

    final secondRun = await service.syncPendingUsers();

    expect(secondRun.synced, 1);
    expect(secondRun.failed, 0);
    expect(remote.callCount, 3);

    final stillPending = await db.usersDao.getPendingSync();
    expect(stillPending, isEmpty);

    final user = await db.usersDao.getById(l2);
    expect(user!.serverId, 22);
    expect(user.pendingSync, isFalse);
  });

  test('saved movies remain linked after sync (the headline assignment requirement)', () async {
    final localId = await insertOfflineUser(firstName: 'Off', lastName: 'Line');
    await db.moviesDao.upsertMovie(
      MoviesCompanion.insert(id: const Value(550), title: 'Fight Club'),
    );
    await db.savedMoviesDao.save(userId: localId, movieId: 550);

    final remote = _FakeRemote(scriptedIds: [777]);
    final service = SyncService(usersDao: db.usersDao, remote: remote);

    await service.syncPendingUsers();

    final saved = await db.savedMoviesDao.watchSavedFor(localId).first;
    expect(saved, hasLength(1));
    expect(saved.first.title, 'Fight Club');

    final user = await db.usersDao.getById(localId);
    expect(user!.serverId, 777);
  });

  test('empty pending list returns SyncResult.empty without calling remote', () async {
    final remote = _FakeRemote();
    final service = SyncService(usersDao: db.usersDao, remote: remote);

    final result = await service.syncPendingUsers();

    expect(result.synced, 0);
    expect(result.failed, 0);
    expect(remote.callCount, 0);
  });
}
