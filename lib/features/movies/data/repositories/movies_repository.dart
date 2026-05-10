import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/movies_dao.dart';
import '../../../../core/database/database_provider.dart';
import '../datasources/movies_remote_datasource.dart';
import '../models/tmdb_movie.dart';

/// Fetches trending movies from TMDB and writes them into the local cache.
/// The Movies page reads its list from the in-memory pagination state
/// (preserves TMDB's "trending today" ordering); the DB cache exists so the
/// Saved Movies and Movie Detail pages work offline for any movie the user
/// has previously seen.
class MoviesRepository {
  MoviesRepository({required this.remote, required this.moviesDao});

  final MoviesRemoteDataSource remote;
  final MoviesDao moviesDao;

  Future<TmdbMoviePage> fetchTrendingPage(int page) async {
    final apiPage = await remote.fetchTrending(page: page);
    if (apiPage.movies.isNotEmpty) {
      await moviesDao.upsertMany(
        apiPage.movies.map(_toCompanion).toList(),
      );
    }
    return apiPage;
  }

  Future<TmdbMovie> fetchDetailAndCache(int movieId) async {
    final movie = await remote.fetchDetail(movieId);
    await moviesDao.upsertMovie(_toCompanion(movie));
    return movie;
  }

  MoviesCompanion _toCompanion(TmdbMovie m) {
    return MoviesCompanion.insert(
      id: Value(m.id),
      title: m.title,
      overview: Value(m.overview),
      posterPath: Value(m.posterPath),
      releaseDate: Value(m.releaseDate),
    );
  }
}

final moviesRepositoryProvider = Provider<MoviesRepository>((ref) {
  return MoviesRepository(
    remote: ref.watch(moviesRemoteDataSourceProvider),
    moviesDao: ref.watch(moviesDaoProvider),
  );
});
