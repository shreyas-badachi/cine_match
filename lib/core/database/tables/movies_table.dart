import 'package:drift/drift.dart';

@DataClassName('Movie')
class Movies extends Table {
  // TMDB movie id is the primary key. Movies are always fetched from the
  // server, so we trust the upstream id and never assign locally.
  IntColumn get id => integer()();

  TextColumn get title => text()();
  TextColumn get overview => text().nullable()();

  // Stored as the relative path from TMDB ("/abc.jpg"). Full URL is
  // assembled at render time — keeps storage compact and resolution-agnostic.
  TextColumn get posterPath => text().nullable()();

  // ISO date string ("2008-07-18"). Stored as text rather than DateTime
  // to preserve nullability and avoid timezone ambiguity from TMDB.
  TextColumn get releaseDate => text().nullable()();

  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
