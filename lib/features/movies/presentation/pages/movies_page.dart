import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../routes/app_router.dart';
import '../providers/movies_providers.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_card_skeleton.dart';

class MoviesPage extends ConsumerStatefulWidget {
  const MoviesPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  final _scrollController = ScrollController();

  int get _userId => int.parse(widget.userId);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Only triggers a fetch if no pages have been loaded yet — the
      // pagination provider is keepAlive, so re-entering Movies for a
      // different user doesn't redundantly re-fetch trending.
      ref.read(moviesPaginationProvider.notifier).loadNextPage();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(moviesPaginationProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagination = ref.watch(moviesPaginationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved movies',
            onPressed: () => context.pushNamed(
              AppRoute.savedMovies,
              pathParameters: {'userId': widget.userId},
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'Matches',
            onPressed: () => context.pushNamed(AppRoute.matches),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(moviesPaginationProvider.notifier).refresh(),
        child: _MoviesBody(
          userId: _userId,
          state: pagination,
          scrollController: _scrollController,
          onRetry: () =>
              ref.read(moviesPaginationProvider.notifier).loadNextPage(),
        ),
      ),
    );
  }
}

class _MoviesBody extends StatelessWidget {
  const _MoviesBody({
    required this.userId,
    required this.state,
    required this.scrollController,
    required this.onRetry,
  });

  final int userId;
  final MoviesPaginationState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.movies.isEmpty && state.isLoading) {
      return const MovieCardListSkeleton();
    }

    if (state.movies.isEmpty) {
      return _EmptyOrError(
        errorMessage: state.errorMessage,
        onRetry: onRetry,
      );
    }

    final showFooter = state.isLoading || state.hasError;
    final itemCount = state.movies.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Gap(AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index >= state.movies.length) {
          return state.hasError
              ? _PaginationErrorTile(onRetry: onRetry)
              : const MovieCardSkeleton();
        }
        final movie = state.movies[index];
        return MovieCard(
          userId: userId,
          movie: movie,
          onTap: () => context.pushNamed(
            AppRoute.movieDetail,
            pathParameters: {'movieId': movie.id.toString()},
            queryParameters: {'userId': userId.toString()},
          ),
        )
            .animate(delay: ((index % 10) * 50).ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class _EmptyOrError extends StatelessWidget {
  const _EmptyOrError({this.errorMessage, required this.onRetry});

  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = errorMessage != null;
    return ListView(
      // ListView (not Center) so RefreshIndicator can pull-to-refresh
      // even when the body is "empty".
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      children: [
        Icon(
          isError ? Icons.cloud_off_outlined : Icons.movie_outlined,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const Gap(AppSpacing.md),
        Text(
          isError ? 'Cannot reach TMDB' : 'No trending movies right now',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(AppSpacing.xs),
        Text(
          errorMessage ?? 'Pull down to refresh.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppSpacing.lg),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _PaginationErrorTile extends StatelessWidget {
  const _PaginationErrorTile({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const Gap(AppSpacing.xs),
            Text(
              'Tap to retry loading more',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
