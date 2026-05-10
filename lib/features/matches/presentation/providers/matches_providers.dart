import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/daos/saved_movies_dao.dart';
import '../../../../core/database/database_provider.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Live list of movies saved by 2 or more users. Reads entirely from the
/// local DB — `savedMoviesDao.watchMatches` is a custom SQL `customSelect`
/// declared with `readsFrom: {savedMovies, movies}`, so any save/unsave
/// anywhere in the app re-emits this stream automatically.
final matchesStreamProvider =
    StreamProvider<List<MovieMatch>>((ref) {
  return ref.watch(savedMoviesDaoProvider).watchMatches();
});

/// Total number of users currently in the app. Used to detect "every user
/// saved this" — the spec calls these out as the highlighted top pick.
final totalUsersCountProvider = Provider<int>((ref) {
  final users = ref.watch(usersStreamProvider).valueOrNull ?? const [];
  return users.length;
});
