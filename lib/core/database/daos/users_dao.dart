import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/saved_movies_table.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

class UserWithSavedCount {
  const UserWithSavedCount({required this.user, required this.savedCount});
  final User user;
  final int savedCount;
}

@DriftAccessor(tables: [Users, SavedMovies])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<User?> getById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Stream<User?> watchById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).watchSingleOrNull();

  Future<User?> getByServerId(int serverId) =>
      (select(users)..where((u) => u.serverId.equals(serverId)))
          .getSingleOrNull();

  Future<List<User>> getPendingSync() =>
      (select(users)..where((u) => u.pendingSync.equals(true))).get();

  /// Refreshes the locally-cached profile for an already-known user. Does
  /// not touch sync flags — used when the API returns updated info for a
  /// user that already exists in the DB.
  Future<void> updateProfile({
    required int localId,
    required String firstName,
    required String lastName,
    String? email,
    String? avatarUrl,
  }) async {
    await (update(users)..where((u) => u.id.equals(localId))).write(
      UsersCompanion(
        firstName: Value(firstName),
        lastName: Value(lastName),
        email: Value(email),
        avatarUrl: Value(avatarUrl),
      ),
    );
  }

  Future<int> markSynced({required int localId, required int serverId}) {
    return (update(users)..where((u) => u.id.equals(localId))).write(
      UsersCompanion(
        serverId: Value(serverId),
        pendingSync: const Value(false),
      ),
    );
  }

  // Drives the Users page. Each row carries the user plus their live
  // saved-movie count via a LEFT OUTER JOIN — users with zero saves still appear.
  Stream<List<UserWithSavedCount>> watchAllWithSavedCount() {
    final countExp = savedMovies.movieId.count();
    final query = select(users).join([
      leftOuterJoin(savedMovies, savedMovies.userId.equalsExp(users.id)),
    ])
      ..addColumns([countExp])
      ..groupBy([users.id])
      ..orderBy([
        OrderingTerm(
          expression: users.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => UserWithSavedCount(
                  user: row.readTable(users),
                  savedCount: row.read(countExp) ?? 0,
                ),
              )
              .toList(),
        );
  }
}
