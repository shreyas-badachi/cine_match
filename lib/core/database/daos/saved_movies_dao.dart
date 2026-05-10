import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/movies_table.dart';
import '../tables/saved_movies_table.dart';
import '../tables/users_table.dart';

part 'saved_movies_dao.g.dart';

class MovieMatch {
  const MovieMatch({
    required this.movieId,
    required this.title,
    required this.posterPath,
    required this.releaseDate,
    required this.saveCount,
    required this.userIds,
  });

  final int movieId;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final int saveCount;
  final List<int> userIds;
}

@DriftAccessor(tables: [SavedMovies, Movies, Users])
class SavedMoviesDao extends DatabaseAccessor<AppDatabase>
    with _$SavedMoviesDaoMixin {
  SavedMoviesDao(super.db);

  // INSERT OR IGNORE — repeat-saves are silent no-ops thanks to the
  // composite primary key (userId, movieId).
  Future<void> save({required int userId, required int movieId}) async {
    await into(savedMovies).insert(
      SavedMoviesCompanion.insert(userId: userId, movieId: movieId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<int> unsave({required int userId, required int movieId}) {
    return (delete(savedMovies)
          ..where(
            (s) => s.userId.equals(userId) & s.movieId.equals(movieId),
          ))
        .go();
  }

  Stream<bool> watchIsSaved({required int userId, required int movieId}) {
    return (select(savedMovies)
          ..where(
            (s) => s.userId.equals(userId) & s.movieId.equals(movieId),
          ))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  // Drives the live count badge on every movie card.
  Stream<int> watchSaveCount(int movieId) {
    final count = savedMovies.userId.count();
    final query = selectOnly(savedMovies)
      ..addColumns([count])
      ..where(savedMovies.movieId.equals(movieId));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  // Drives the Saved Movies page. INNER JOIN guarantees every saved entry
  // has a matching cached movie row, which is why MoviesDao.upsertMovie
  // must be called before SavedMoviesDao.save in the save flow.
  Stream<List<Movie>> watchSavedFor(int userId) {
    final query = select(movies).join([
      innerJoin(savedMovies, savedMovies.movieId.equalsExp(movies.id)),
    ])
      ..where(savedMovies.userId.equals(userId))
      ..orderBy([
        OrderingTerm(
          expression: savedMovies.savedAt,
          mode: OrderingMode.desc,
        ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(movies)).toList());
  }

  // Drives the "N users want to watch this" line on Movie Detail.
  // Joined with users so the row carries the avatar URL for the small
  // profile photos shown next to the message.
  Stream<List<User>> watchUsersWhoSaved(int movieId) {
    final query = select(users).join([
      innerJoin(savedMovies, savedMovies.userId.equalsExp(users.id)),
    ])
      ..where(savedMovies.movieId.equals(movieId))
      ..orderBy([
        OrderingTerm(
          expression: savedMovies.savedAt,
          mode: OrderingMode.asc,
        ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(users)).toList());
  }

  // The heart of the app: Matches page query. Movies saved by 2+ users,
  // sorted by save count desc. The `readsFrom` set tells Drift to re-emit
  // whenever savedMovies OR movies changes — so a single save() call
  // updates the Movies card badge, the Saved Movies list, AND the
  // Matches page in one shot, with zero manual refresh logic.
  Stream<List<MovieMatch>> watchMatches() {
    return customSelect(
      '''
      SELECT
        m.id              AS movie_id,
        m.title           AS title,
        m.poster_path     AS poster_path,
        m.release_date    AS release_date,
        COUNT(s.user_id)  AS save_count,
        GROUP_CONCAT(s.user_id) AS user_ids
      FROM saved_movies s
      INNER JOIN movies m ON m.id = s.movie_id
      GROUP BY s.movie_id
      HAVING COUNT(s.user_id) >= 2
      ORDER BY save_count DESC, m.title ASC
      ''',
      readsFrom: {savedMovies, movies},
    ).watch().map(
          (rows) => rows
              .map(
                (r) => MovieMatch(
                  movieId: r.read<int>('movie_id'),
                  title: r.read<String>('title'),
                  posterPath: r.read<String?>('poster_path'),
                  releaseDate: r.read<String?>('release_date'),
                  saveCount: r.read<int>('save_count'),
                  userIds: r
                      .read<String>('user_ids')
                      .split(',')
                      .map(int.parse)
                      .toList(),
                ),
              )
              .toList(),
        );
  }
}
