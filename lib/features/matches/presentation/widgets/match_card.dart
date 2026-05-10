import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/database/daos/saved_movies_dao.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../users/presentation/providers/users_providers.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.isTopPick,
    required this.onTap,
  });

  final MovieMatch match;
  final bool isTopPick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isTopPick
          ? AppColors.accentAmber.withValues(alpha: 0.10)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: isTopPick
            ? const BorderSide(color: AppColors.accentAmber, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTopPick) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    top: AppSpacing.xxs,
                    bottom: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: AppColors.accentAmber,
                      ),
                      const Gap(AppSpacing.xxs),
                      Text(
                        'TOP PICK · everyone saved this',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Poster(
                    movieId: match.movieId,
                    posterPath: match.posterPath,
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (match.releaseDate != null) ...[
                            const Gap(AppSpacing.xxs),
                            Text(
                              _yearFromDate(match.releaseDate),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const Gap(AppSpacing.xs),
                          _SaverAvatars(
                            userIds: match.userIds,
                            saveCount: match.saveCount,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _yearFromDate(String? iso) {
    if (iso == null || iso.length < 4) return '';
    return iso.substring(0, 4);
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
      flightShuttleBuilder: (_, _, _, _, _) =>
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
      return Container(
        color: AppColors.surfaceContainer,
        alignment: Alignment.center,
        child: Icon(
          Icons.movie_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: '${ApiEndpoints.tmdbImageW185}$posterPath',
      fit: BoxFit.cover,
      fadeInDuration: AppDuration.normal,
      placeholder: (_, _) => Container(color: AppColors.surfaceContainer),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surfaceContainer,
        alignment: Alignment.center,
        child: const Icon(Icons.movie_outlined),
      ),
    );
  }
}

class _SaverAvatars extends ConsumerWidget {
  const _SaverAvatars({required this.userIds, required this.saveCount});

  final List<int> userIds;
  final int saveCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visible = userIds.take(4).toList();
    final remaining = saveCount - visible.length;
    final phrase =
        saveCount == 1 ? '1 save' : '$saveCount saves';

    return Row(
      children: [
        SizedBox(
          width: visible.length * 22.0 + 6,
          height: 28,
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  left: i * 22.0,
                  child: _SaverAvatar(userId: visible[i]),
                ),
            ],
          ),
        ),
        const Gap(AppSpacing.xs),
        Flexible(
          child: Text(
            remaining > 0 ? '$phrase (+$remaining)' : phrase,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SaverAvatar extends ConsumerWidget {
  const _SaverAvatar({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userByIdProvider(userId)).valueOrNull;
    final url = user?.avatarUrl;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainer,
        border: Border.all(color: AppColors.surfaceDim, width: 2),
      ),
      child: ClipOval(
        child: (url == null || url.isEmpty)
            ? Icon(
                Icons.person,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.surfaceContainer),
                errorWidget: (_, _, _) => Icon(
                  Icons.person,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
