import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/movies_dao.dart';
import '../../../../core/database/daos/saved_movies_dao.dart';
import '../../../../core/database/database_provider.dart';

/// Owns the user↔movie relationship table.
///
/// `save` is FK-safe — it always upserts the movie row before inserting into
/// `saved_movies`, so callers don't have to remember the ordering. This is
/// load-bearing for the Movie Detail page, which lets a user save a movie
/// fetched from `/movie/{id}` that may not yet be cached from a trending list.
class SavedMoviesRepository {
  SavedMoviesRepository({
    required this.savedMoviesDao,
    required this.moviesDao,
  });

  final SavedMoviesDao savedMoviesDao;
  final MoviesDao moviesDao;

  Future<void> save({
    required int userId,
    required int movieId,
    required String title,
    String? overview,
    String? posterPath,
    String? releaseDate,
  }) async {
    await moviesDao.upsertMovie(
      MoviesCompanion.insert(
        id: Value(movieId),
        title: title,
        overview: Value(overview),
        posterPath: Value(posterPath),
        releaseDate: Value(releaseDate),
      ),
    );
    await savedMoviesDao.save(userId: userId, movieId: movieId);
  }

  Future<void> unsave({
    required int userId,
    required int movieId,
  }) async {
    await savedMoviesDao.unsave(userId: userId, movieId: movieId);
  }
}

final savedMoviesRepositoryProvider =
    Provider<SavedMoviesRepository>((ref) {
  return SavedMoviesRepository(
    savedMoviesDao: ref.watch(savedMoviesDaoProvider),
    moviesDao: ref.watch(moviesDaoProvider),
  );
});
