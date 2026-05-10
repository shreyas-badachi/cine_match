import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/movies_dao.dart';
import 'daos/saved_movies_dao.dart';
import 'daos/users_dao.dart';
import 'tables/movies_table.dart';
import 'tables/saved_movies_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Users, Movies, SavedMovies],
  daos: [UsersDao, MoviesDao, SavedMoviesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // SQLite ignores foreign keys by default. Without this PRAGMA the
          // ON DELETE CASCADE on SavedMovies would silently do nothing.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cine_match.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
