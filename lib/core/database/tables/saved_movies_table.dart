import 'package:drift/drift.dart';

import 'movies_table.dart';
import 'users_table.dart';

@DataClassName('SavedMovie')
class SavedMovies extends Table {
  // Composite primary key (userId, movieId) makes duplicate saves
  // physically impossible at the database layer. INSERT OR IGNORE
  // turns repeat-saves into a silent no-op, so the UI can be naive.
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();

  IntColumn get movieId => integer().references(
        Movies,
        #id,
        onDelete: KeyAction.cascade,
      )();

  DateTimeColumn get savedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId, movieId};
}
