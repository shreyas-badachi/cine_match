// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movies_dao.dart';

// ignore_for_file: type=lint
mixin _$MoviesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MoviesTable get movies => attachedDatabase.movies;
  MoviesDaoManager get managers => MoviesDaoManager(this);
}

class MoviesDaoManager {
  final _$MoviesDaoMixin _db;
  MoviesDaoManager(this._db);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db.attachedDatabase, _db.movies);
}
