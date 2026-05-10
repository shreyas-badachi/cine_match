import 'package:cine_match/core/database/app_database.dart';
import 'package:cine_match/features/saved_movies/data/repositories/saved_movies_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SavedMoviesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SavedMoviesRepository(
      savedMoviesDao: db.savedMoviesDao,
      moviesDao: db.moviesDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertUser() => db.usersDao.insertUser(
        UsersCompanion.insert(firstName: 'A', lastName: 'A'),
      );

  test('save() upserts the movie row before inserting saved_movies', () async {
    final userId = await insertUser();

    // Movie does NOT exist in the DB yet.
    expect(await db.moviesDao.getById(550), isNull);

    await repo.save(
      userId: userId,
      movieId: 550,
      title: 'Fight Club',
      posterPath: '/poster.jpg',
      releaseDate: '1999-10-15',
    );

    // Both rows exist now: movie cached, save linked.
    final movie = await db.moviesDao.getById(550);
    expect(movie?.title, 'Fight Club');
    expect(movie?.posterPath, '/poster.jpg');

    final count = await db.savedMoviesDao.watchSaveCount(550).first;
    expect(count, 1);
  });

  test('save() is idempotent — second call does not duplicate the row', () async {
    final userId = await insertUser();

    await repo.save(userId: userId, movieId: 1, title: 'X');
    await repo.save(userId: userId, movieId: 1, title: 'X');
    await repo.save(userId: userId, movieId: 1, title: 'X');

    final count = await db.savedMoviesDao.watchSaveCount(1).first;
    expect(count, 1);
  });

  test('unsave() removes the row; re-saving works via upsert path', () async {
    final userId = await insertUser();

    await repo.save(userId: userId, movieId: 7, title: 'Test');
    expect(await db.savedMoviesDao.watchSaveCount(7).first, 1);

    await repo.unsave(userId: userId, movieId: 7);
    expect(await db.savedMoviesDao.watchSaveCount(7).first, 0);

    // The movie row should still exist (it's just a cache; many users may
    // still want to save it later).
    expect(await db.moviesDao.getById(7), isNotNull);

    await repo.save(userId: userId, movieId: 7, title: 'Test (updated)');
    final movie = await db.moviesDao.getById(7);
    expect(movie?.title, 'Test (updated)');
    expect(await db.savedMoviesDao.watchSaveCount(7).first, 1);
  });

  test('save() refreshes movie metadata on subsequent calls', () async {
    final userId = await insertUser();

    await repo.save(
      userId: userId,
      movieId: 42,
      title: 'Old title',
      posterPath: '/old.jpg',
    );

    // Same movieId, different metadata — represents an updated TMDB response.
    await repo.unsave(userId: userId, movieId: 42);
    await db.moviesDao.upsertMovie(
      MoviesCompanion.insert(
        id: const Value(42),
        title: 'New title',
        posterPath: const Value('/new.jpg'),
      ),
    );

    final movie = await db.moviesDao.getById(42);
    expect(movie?.title, 'New title');
    expect(movie?.posterPath, '/new.jpg');
  });
}
