import 'package:drift/drift.dart';

class Users extends Table {
  // Stable local primary key. Never changes, even after server sync.
  // SavedMovies.userId references this column, so saves stay correctly
  // linked to their user no matter what the server assigns.
  IntColumn get id => integer().autoIncrement()();

  // Server-assigned ID from Reqres. NULL until sync completes.
  // UNIQUE prevents duplicate-import on retry; multiple NULLs are allowed
  // (SQLite default), so multiple offline users can coexist.
  IntColumn get serverId => integer().nullable().unique()();

  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get email => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  // Reqres "job" field repurposed as the user's movie taste.
  TextColumn get movieTaste => text().nullable()();

  // True when the user was created offline and still needs to be POSTed.
  BoolColumn get pendingSync =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
