// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_dao.dart';

// ignore_for_file: type=lint
mixin _$UsersDaoMixin on DatabaseAccessor<AppDatabase> {
  $UsersTable get users => attachedDatabase.users;
  $MoviesTable get movies => attachedDatabase.movies;
  $SavedMoviesTable get savedMovies => attachedDatabase.savedMovies;
  UsersDaoManager get managers => UsersDaoManager(this);
}

class UsersDaoManager {
  final _$UsersDaoMixin _db;
  UsersDaoManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db.attachedDatabase, _db.movies);
  $$SavedMoviesTableTableManager get savedMovies =>
      $$SavedMoviesTableTableManager(_db.attachedDatabase, _db.savedMovies);
}
