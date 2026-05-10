import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/movies_table.dart';

part 'movies_dao.g.dart';

@DriftAccessor(tables: [Movies])
class MoviesDao extends DatabaseAccessor<AppDatabase> with _$MoviesDaoMixin {
  MoviesDao(super.db);

  // Upsert: insert or update on conflict. Used when caching API responses
  // so a re-fetch of the same movie refreshes title/poster/overview without
  // creating a duplicate row.
  Future<void> upsertMovie(MoviesCompanion movie) {
    return into(movies).insertOnConflictUpdate(movie);
  }

  Future<void> upsertMany(List<MoviesCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(movies, entries));
  }

  Future<Movie?> getById(int id) =>
      (select(movies)..where((m) => m.id.equals(id))).getSingleOrNull();

  Stream<Movie?> watchById(int id) =>
      (select(movies)..where((m) => m.id.equals(id))).watchSingleOrNull();
}
