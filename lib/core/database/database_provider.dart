import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

// Riverpod owns the database lifecycle. The connection is opened lazily on
// first read (LazyDatabase inside _openConnection) and closed automatically
// when the provider is disposed — so widget tests that never read this
// provider don't pay the cost of opening a real SQLite file.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final usersDaoProvider = Provider((ref) => ref.watch(appDatabaseProvider).usersDao);
final moviesDaoProvider = Provider((ref) => ref.watch(appDatabaseProvider).moviesDao);
final savedMoviesDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).savedMoviesDao);
