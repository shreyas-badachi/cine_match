import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

/// Live saved-movies list for a single user. Backed entirely by the local
/// DB — works offline by design (no network involvement at all).
final savedMoviesForUserProvider =
    StreamProvider.family<List<Movie>, int>((ref, userId) {
  return ref.watch(savedMoviesDaoProvider).watchSavedFor(userId);
});
