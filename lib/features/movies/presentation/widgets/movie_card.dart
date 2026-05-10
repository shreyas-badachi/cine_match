import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../data/models/tmdb_movie.dart';
import '../providers/movies_providers.dart';
import 'save_button.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.userId,
    required this.movie,
    required this.onTap,
  });

  final int userId;
  final TmdbMovie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Poster(movieId: movie.id, posterPath: movie.posterPath),
              const Gap(AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(AppSpacing.xxs),
                      Text(
                        movie.releaseYear ?? 'Release date unknown',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      _SaveCountBadge(movieId: movie.id),
                    ],
                  ),
                ),
              ),
              SaveButton(userId: userId, movie: movie),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.movieId, required this.posterPath});

  final int movieId;
  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'movie-poster-$movieId',
      // Hero requires Material wrapping during flight to avoid black box
      // on cards that have InkWell ripples mid-flight.
      flightShuttleBuilder: (_, animation, _, _, _) =>
          _PosterImage(posterPath: posterPath),
      child: SizedBox(
        width: 90,
        height: 135,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _PosterImage(posterPath: posterPath),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.posterPath});

  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    if (posterPath == null) {
      return const _PosterFallback();
    }
    return CachedNetworkImage(
      imageUrl: '${ApiEndpoints.tmdbImageW185}$posterPath',
      fit: BoxFit.cover,
      fadeInDuration: AppDuration.normal,
      placeholder: (_, _) => Container(color: AppColors.surfaceContainer),
      errorWidget: (_, _, _) => const _PosterFallback(),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}

class _SaveCountBadge extends ConsumerWidget {
  const _SaveCountBadge({required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(saveCountProvider(movieId));
    final count = countAsync.valueOrNull ?? 0;
    final hasSaves = count > 0;

    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: AppDuration.fast,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        // Distinct keys per count value so AnimatedSwitcher animates the swap.
        key: ValueKey(count),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasSaves
              ? AppColors.accentAmber.withValues(alpha: 0.15)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          hasSaves
              ? (count == 1 ? '1 user saved' : '$count users saved')
              : 'No saves yet',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: hasSaves
                ? AppColors.accentAmber
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
