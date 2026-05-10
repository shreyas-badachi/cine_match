// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_movies_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedMoviesDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
  $MoviesTable get movies => attachedDatabase.movies;
  $SavedMoviesTable get savedMovies => attachedDatabase.savedMovies;
  SavedMoviesDaoManager get managers => SavedMoviesDaoManager(this);
}

class SavedMoviesDaoManager {
  final _$SavedMoviesDaoMixin _db;
  SavedMoviesDaoManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db.attachedDatabase, _db.movies);
  $$SavedMoviesTableTableManager get savedMovies =>
      $$SavedMoviesTableTableManager(_db.attachedDatabase, _db.savedMovies);
}
