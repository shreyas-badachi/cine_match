import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../data/models/tmdb_movie.dart';
import '../../../saved_movies/data/repositories/saved_movies_repository.dart';
import '../providers/movies_providers.dart';

/// Animated bookmark toggle. Reads `isSaved` as a Stream so the icon updates
/// the moment the DB changes — no manual setState. Tap dispatches save/unsave
/// through `SavedMoviesRepository`, which handles the FK guarantee.
class SaveButton extends ConsumerWidget {
  const SaveButton({
    super.key,
    required this.userId,
    required this.movie,
  });

  final int userId;
  final TmdbMovie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSavedAsync = ref.watch(
      isSavedProvider((userId: userId, movieId: movie.id)),
    );
    final isSaved = isSavedAsync.valueOrNull ?? false;

    return IconButton(
      tooltip: isSaved ? 'Remove from saved' : 'Save movie',
      onPressed: () async {
        final repo = ref.read(savedMoviesRepositoryProvider);
        if (isSaved) {
          await repo.unsave(userId: userId, movieId: movie.id);
        } else {
          await repo.save(
            userId: userId,
            movieId: movie.id,
            title: movie.title,
            overview: movie.overview,
            posterPath: movie.posterPath,
            releaseDate: movie.releaseDate,
          );
        }
      },
      icon: AnimatedSwitcher(
        duration: AppDuration.fast,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_outline,
          key: ValueKey(isSaved),
          color: isSaved
              ? AppColors.accentAmber
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
