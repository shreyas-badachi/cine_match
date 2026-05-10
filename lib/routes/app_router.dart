import 'package:go_router/go_router.dart';

import '../features/matches/presentation/pages/matches_page.dart';
import '../features/movies/presentation/pages/movie_detail_page.dart';
import '../features/movies/presentation/pages/movies_page.dart';
import '../features/saved_movies/presentation/pages/saved_movies_page.dart';
import '../features/users/presentation/pages/add_user_page.dart';
import '../features/users/presentation/pages/users_page.dart';

abstract final class AppRoute {
  static const users = 'users';
  static const addUser = 'addUser';
  static const movies = 'movies';
  static const savedMovies = 'savedMovies';
  static const movieDetail = 'movieDetail';
  static const matches = 'matches';
}

abstract final class AppRouter {
  static final GoRouter config = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.users,
        builder: (context, state) => const UsersPage(),
        routes: [
          GoRoute(
            path: 'users/add',
            name: AppRoute.addUser,
            builder: (context, state) => const AddUserPage(),
          ),
          GoRoute(
            path: 'users/:userId/movies',
            name: AppRoute.movies,
            builder: (context, state) =>
                MoviesPage(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: 'users/:userId/saved',
            name: AppRoute.savedMovies,
            builder: (context, state) =>
                SavedMoviesPage(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: 'movies/:movieId',
            name: AppRoute.movieDetail,
            builder: (context, state) => MovieDetailPage(
              movieId: state.pathParameters['movieId']!,
              activeUserId: state.uri.queryParameters['userId'],
            ),
          ),
          GoRoute(
            path: 'matches',
            name: AppRoute.matches,
            builder: (context, state) => const MatchesPage(),
          ),
        ],
      ),
    ],
  );
}
