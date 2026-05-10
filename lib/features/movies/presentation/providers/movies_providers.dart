import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/models/tmdb_movie.dart';
import '../../data/repositories/movies_repository.dart';

class MoviesPaginationState {
  const MoviesPaginationState({
    this.movies = const [],
    this.currentPage = 0,
    this.totalPages = 1,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<TmdbMovie> movies;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  bool get hasMore => currentPage == 0 || currentPage < totalPages;

  static const initial = MoviesPaginationState();

  MoviesPaginationState copyWith({
    List<TmdbMovie>? movies,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MoviesPaginationState(
      movies: movies ?? this.movies,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MoviesPaginationNotifier extends StateNotifier<MoviesPaginationState> {
  MoviesPaginationNotifier(this._repository)
      : super(MoviesPaginationState.initial);

  final MoviesRepository _repository;

  Future<void> loadNextPage() async {
    if (state.isLoading) return;
    if (!state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final next = state.currentPage + 1;
      final apiPage = await _repository.fetchTrendingPage(next);
      state = state.copyWith(
        movies: [...state.movies, ...apiPage.movies],
        currentPage: next,
        totalPages: apiPage.totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load movies. Tap to retry.',
      );
    }
  }

  Future<void> refresh() async {
    state = MoviesPaginationState.initial;
    await loadNextPage();
  }
}

final moviesPaginationProvider = StateNotifierProvider<
    MoviesPaginationNotifier, MoviesPaginationState>((ref) {
  return MoviesPaginationNotifier(ref.watch(moviesRepositoryProvider));
});

/// Live save count for a single movie. Used by the count badge.
final saveCountProvider =
    StreamProvider.family<int, int>((ref, movieId) {
  return ref.watch(savedMoviesDaoProvider).watchSaveCount(movieId);
});

/// Live `isSaved` for a (user, movie) pair. Used by the Save button.
final isSavedProvider = StreamProvider.family<bool, ({int userId, int movieId})>(
  (ref, args) {
    return ref.watch(savedMoviesDaoProvider).watchIsSaved(
          userId: args.userId,
          movieId: args.movieId,
        );
  },
);

/// Fetches movie detail from TMDB and writes it to the cache. The result
/// is itself the source for the Movie Detail page UI. AutoDispose keeps
/// the cache from growing unbounded as users browse different movies.
final movieDetailProvider =
    FutureProvider.autoDispose.family<TmdbMovie, int>((ref, movieId) {
  return ref.watch(moviesRepositoryProvider).fetchDetailAndCache(movieId);
});

/// Drives the "N users want to watch this" line on Movie Detail.
/// Live — adds new avatars as users save the movie in real time.
final usersWhoSavedProvider =
    StreamProvider.family<List<User>, int>((ref, movieId) {
  return ref.watch(savedMoviesDaoProvider).watchUsersWhoSaved(movieId);
});
