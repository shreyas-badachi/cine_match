import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../routes/app_router.dart';
import '../../../movies/data/models/tmdb_movie.dart';
import '../../../movies/presentation/widgets/movie_card.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../providers/saved_movies_providers.dart';

class SavedMoviesPage extends ConsumerWidget {
  const SavedMoviesPage({super.key, required this.userId});

  final String userId;

  int get _userId => int.parse(userId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByIdProvider(_userId));
    final savedAsync = ref.watch(savedMoviesForUserProvider(_userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved movies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'Matches',
            onPressed: () => context.pushNamed(AppRoute.matches),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _UserHeader(user: userAsync.valueOrNull),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: savedAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Could not load: $e')),
              ),
              data: (movies) => movies.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySavedState(),
                    )
                  : SliverList.separated(
                      itemCount: movies.length,
                      separatorBuilder: (_, _) => const Gap(AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final movie = movies[index];
                        return MovieCard(
                          userId: _userId,
                          movie: movie.toTmdb(),
                          onTap: () => context.pushNamed(
                            AppRoute.movieDetail,
                            pathParameters: {'movieId': movie.id.toString()},
                            queryParameters: {'userId': _userId.toString()},
                          ),
                        )
                            .animate(delay: ((index % 10) * 50).ms)
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.08, end: 0);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const SizedBox(height: 96);
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _HeaderAvatar(url: user!.avatarUrl),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user!.firstName} ${user!.lastName}'.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (user!.movieTaste != null && user!.movieTaste!.isNotEmpty) ...[
                  const Gap(AppSpacing.xxs),
                  Text(
                    user!.movieTaste!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.surfaceContainer,
        child: Icon(
          Icons.person,
          size: 28,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: 64,
          height: 64,
          color: AppColors.surfaceContainer,
        ),
        errorWidget: (_, _, _) => CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.surfaceContainer,
          child: const Icon(Icons.person),
        ),
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const Gap(AppSpacing.md),
          Text(
            'No saved movies yet',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Gap(AppSpacing.xs),
          Text(
            'Browse the trending list and tap the bookmark to save movies for later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
