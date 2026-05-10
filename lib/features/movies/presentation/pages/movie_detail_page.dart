import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../data/models/tmdb_movie.dart';
import '../providers/movies_providers.dart';
import '../widgets/save_button.dart';

class MovieDetailPage extends ConsumerWidget {
  const MovieDetailPage({
    super.key,
    required this.movieId,
    this.activeUserId,
  });

  final String movieId;
  final String? activeUserId;

  int get _movieId => int.parse(movieId);
  int? get _userId => activeUserId == null ? null : int.tryParse(activeUserId!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(movieDetailProvider(_movieId));

    return Scaffold(
      body: detailAsync.when(
        loading: () => _DetailLoading(movieId: _movieId),
        error: (e, _) => _DetailError(
          message: '$e',
          onRetry: () => ref.invalidate(movieDetailProvider(_movieId)),
        ),
        data: (movie) => _DetailBody(
          movie: movie,
          activeUserId: _userId,
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.movie, required this.activeUserId});

  final TmdbMovie movie;
  final int? activeUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 360,
          pinned: true,
          backgroundColor: AppColors.surfaceDim,
          flexibleSpace: FlexibleSpaceBar(
            background: _LargePoster(
              movieId: movie.id,
              posterPath: movie.posterPath,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.list(
            children: [
              Text(
                movie.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (movie.releaseDate != null) ...[
                const Gap(AppSpacing.xs),
                Text(
                  _formatReleaseDate(movie.releaseDate!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Gap(AppSpacing.lg),
              _SaveRow(movie: movie, activeUserId: activeUserId),
              const Gap(AppSpacing.lg),
              _UsersWhoSavedRow(movieId: movie.id),
              if (movie.overview != null && movie.overview!.isNotEmpty) ...[
                const Gap(AppSpacing.xl),
                Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  movie.overview!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              const Gap(AppSpacing.xxl),
            ],
          ),
        ),
      ],
    );
  }

  String _formatReleaseDate(String iso) {
    // ISO "2008-07-18". TMDB always returns this format. Manual parse is
    // cheap and avoids pulling intl in just for one line.
    if (iso.length < 10) return iso;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final year = iso.substring(0, 4);
    final monthIdx = int.tryParse(iso.substring(5, 7));
    final day = int.tryParse(iso.substring(8, 10));
    if (monthIdx == null || day == null || monthIdx < 1 || monthIdx > 12) {
      return year;
    }
    return '${months[monthIdx - 1]} $day, $year';
  }
}

class _SaveRow extends StatelessWidget {
  const _SaveRow({required this.movie, required this.activeUserId});

  final TmdbMovie movie;
  final int? activeUserId;

  @override
  Widget build(BuildContext context) {
    if (activeUserId == null) {
      return Text(
        'Open this movie from a user to save it.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return Row(
      children: [
        SaveButton(userId: activeUserId!, movie: movie),
        const Gap(AppSpacing.xs),
        Text(
          'Save to your watchlist',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _UsersWhoSavedRow extends ConsumerWidget {
  const _UsersWhoSavedRow({required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersWhoSavedProvider(movieId));
    final users = usersAsync.valueOrNull ?? const <User>[];

    final theme = Theme.of(context);

    if (users.isEmpty) {
      return Text(
        'Be the first to save this.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final visible = users.take(5).toList();
    final remaining = users.length - visible.length;
    final phrase = users.length == 1
        ? '1 user wants to watch this'
        : '${users.length} users want to watch this';

    return Row(
      children: [
        SizedBox(
          width: visible.length * 24.0 + 8,
          height: 32,
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * 24.0,
                  child: _MiniAvatar(url: visible[i].avatarUrl),
                ),
            ],
          ),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: Text(
            remaining > 0 ? '$phrase (+$remaining)' : phrase,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainer,
        border: Border.all(color: AppColors.surfaceDim, width: 2),
      ),
      child: ClipOval(
        child: (url == null || url!.isEmpty)
            ? Icon(
                Icons.person,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                fadeInDuration: AppDuration.fast,
                placeholder: (_, _) =>
                    Container(color: AppColors.surfaceContainer),
                errorWidget: (_, _, _) => Icon(
                  Icons.person,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _LargePoster extends StatelessWidget {
  const _LargePoster({required this.movieId, required this.posterPath});

  final int movieId;
  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'movie-poster-$movieId',
      child: posterPath == null
          ? const _PosterFallback()
          : CachedNetworkImage(
              imageUrl: '${ApiEndpoints.tmdbImageW500}$posterPath',
              fit: BoxFit.cover,
              fadeInDuration: AppDuration.normal,
              placeholder: (_, _) =>
                  Container(color: AppColors.surfaceContainer),
              errorWidget: (_, _, _) => const _PosterFallback(),
            ),
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
        size: 64,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading({required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context) {
    const base = AppColors.surfaceContainer;
    final highlight = Color.lerp(base, Colors.white, 0.08)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 360,
          pinned: true,
          backgroundColor: AppColors.surfaceDim,
          flexibleSpace: FlexibleSpaceBar(
            background: Hero(
              tag: 'movie-poster-$movieId',
              child: Container(color: AppColors.surfaceContainer),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 24,
                    width: 240,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Container(height: 14, width: 140, color: Colors.white),
                  const SizedBox(height: 24),
                  Container(height: 16, width: 200, color: Colors.white),
                  const SizedBox(height: 24),
                  Container(height: 14, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 14, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 200, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const Gap(AppSpacing.md),
              Text(
                'Could not load movie',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(AppSpacing.xs),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const Gap(AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
