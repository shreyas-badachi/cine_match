import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/users_dao.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/repositories/users_repository.dart';

final usersStreamProvider =
    StreamProvider<List<UserWithSavedCount>>((ref) {
  return ref.watch(usersRepositoryProvider).watchAll();
});

/// Live single-user lookup. Used by the Saved Movies page header so the
/// avatar/name/taste reflect any profile updates fetched from Reqres.
final userByIdProvider = StreamProvider.family<User?, int>((ref, userId) {
  return ref.watch(usersDaoProvider).watchById(userId);
});

class UsersPaginationState {
  const UsersPaginationState({
    this.currentPage = 0,
    this.totalPages = 1,
    this.isLoading = false,
    this.errorMessage,
  });

  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  /// `true` if we either haven't fetched anything yet or the API reports
  /// more pages exist past what we've already loaded.
  bool get hasMore => currentPage == 0 || currentPage < totalPages;

  static const initial = UsersPaginationState();

  UsersPaginationState copyWith({
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UsersPaginationState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UsersPaginationNotifier extends StateNotifier<UsersPaginationState> {
  UsersPaginationNotifier(this._repository)
      : super(UsersPaginationState.initial);

  final UsersRepository _repository;

  /// Fetches the next page from Reqres and writes results to the DB. The UI
  /// list updates via the DB Stream — this method does not return data.
  Future<void> loadNextPage() async {
    if (state.isLoading) return;
    if (!state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final next = state.currentPage + 1;
      final apiPage = await _repository.fetchPage(next);
      state = state.copyWith(
        currentPage: next,
        totalPages: apiPage.totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load users. Tap to retry.',
      );
    }
  }

  /// Resets pagination and re-fetches from page 1. Used by pull-to-refresh.
  Future<void> refresh() async {
    state = UsersPaginationState.initial;
    await loadNextPage();
  }
}

final usersPaginationProvider = StateNotifierProvider<
    UsersPaginationNotifier, UsersPaginationState>((ref) {
  return UsersPaginationNotifier(ref.watch(usersRepositoryProvider));
});
