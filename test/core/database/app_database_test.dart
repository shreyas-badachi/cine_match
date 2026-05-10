import 'package:cine_match/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SavedMovies — composite primary key prevents duplicates', () {
    test('saving the same (user, movie) pair twice results in a single row', () async {
      final userId = await db.usersDao.insertUser(
        UsersCompanion.insert(firstName: 'Alex', lastName: 'Doe'),
      );
      await db.moviesDao.upsertMovie(
        MoviesCompanion.insert(id: const Value(550), title: 'Fight Club'),
      );

      await db.savedMoviesDao.save(userId: userId, movieId: 550);
      await db.savedMoviesDao.save(userId: userId, movieId: 550);
      await db.savedMoviesDao.save(userId: userId, movieId: 550);

      final count = await db.savedMoviesDao.watchSaveCount(550).first;
      expect(count, 1);
    });
  });

  group('Offline sync — saved movies stay linked after server ID arrives', () {
    test('markSynced updates serverId without breaking saved_movies links', () async {
      final localId = await db.usersDao.insertUser(
        UsersCompanion.insert(
          firstName: 'Beth',
          lastName: 'Smith',
          pendingSync: const Value(true),
        ),
      );
      await db.moviesDao.upsertMovie(
        MoviesCompanion.insert(id: const Value(680), title: 'Pulp Fiction'),
      );
      await db.savedMoviesDao.save(userId: localId, movieId: 680);

      await db.usersDao.markSynced(localId: localId, serverId: 13);

      final saved = await db.savedMoviesDao.watchSavedFor(localId).first;
      expect(saved, hasLength(1));
      expect(saved.first.title, 'Pulp Fiction');

      final user = await db.usersDao.getById(localId);
      expect(user?.serverId, 13);
      expect(user?.pendingSync, isFalse);
    });

    test('getPendingSync returns only users that still need to be POSTed', () async {
      await db.usersDao.insertUser(
        UsersCompanion.insert(
          firstName: 'Synced',
          lastName: 'User',
          serverId: const Value(7),
        ),
      );
      await db.usersDao.insertUser(
        UsersCompanion.insert(
          firstName: 'Pending',
          lastName: 'User',
          pendingSync: const Value(true),
        ),
      );

      final pending = await db.usersDao.getPendingSync();
      expect(pending, hasLength(1));
      expect(pending.first.firstName, 'Pending');
    });
  });

  group('Matches — movies saved by 2 or more users', () {
    test('only multi-user movies appear, sorted by save count desc', () async {
      final u1 = await db.usersDao.insertUser(
        UsersCompanion.insert(firstName: 'A', lastName: 'A'),
      );
      final u2 = await db.usersDao.insertUser(
        UsersCompanion.insert(firstName: 'B', lastName: 'B'),
      );
      final u3 = await db.usersDao.insertUser(
        UsersCompanion.insert(firstName: 'C', lastName: 'C'),
      );

      await db.moviesDao.upsertMany([
        MoviesCompanion.insert(id: const Value(1), title: 'Group Pick'),
        MoviesCompanion.insert(id: const Value(2), title: 'Solo Pick'),
        MoviesCompanion.insert(id: const Value(3), title: 'Pair Pick'),
      ]);

      await db.savedMoviesDao.save(userId: u1, movieId: 1);
      await db.savedMoviesDao.save(userId: u2, movieId: 1);
      await db.savedMoviesDao.save(userId: u3, movieId: 1);

      await db.savedMoviesDao.save(userId: u1, movieId: 2);

      await db.savedMoviesDao.save(userId: u1, movieId: 3);
      await db.savedMoviesDao.save(userId: u2, movieId: 3);

      final matches = await db.savedMoviesDao.watchMatches().first;

      expect(matches, hasLength(2));
      expect(matches[0].title, 'Group Pick');
      expect(matches[0].saveCount, 3);
      expect(matches[0].userIds.toSet(), {u1, u2, u3});
      expect(matches[1].title, 'Pair Pick');
      expect(matches[1].saveCount, 2);
    });
  });

  group('Foreign keys — cascade delete', () {
    test('deleting a user removes their saved_movies (PRAGMA foreign_keys ON)', () async {
      final userId = await db.usersDao.insertUser(
        UsersCompanion.insert(firstName: 'X', lastName: 'X'),
      );
      await db.moviesDao.upsertMovie(
        MoviesCompanion.insert(id: const Value(999), title: 'Test'),
      );
      await db.savedMoviesDao.save(userId: userId, movieId: 999);

      await (db.delete(db.users)..where((u) => u.id.equals(userId))).go();

      final count = await db.savedMoviesDao.watchSaveCount(999).first;
      expect(count, 0);
    });
  });
}
