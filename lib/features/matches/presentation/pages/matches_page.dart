import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../routes/app_router.dart';
import '../providers/matches_providers.dart';
import '../widgets/match_card.dart';

class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesStreamProvider);
    final totalUsers = ref.watch(totalUsersCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: matchesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (matches) {
          if (matches.isEmpty) {
            return const _EmptyMatchesState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const Gap(AppSpacing.xs),
            itemBuilder: (context, index) {
              final match = matches[index];
              // "Top pick" — every user in the app saved this movie. Only
              // meaningful when there are 2+ users (otherwise "everyone" is
              // a low bar).
              final isTopPick =
                  totalUsers >= 2 && match.saveCount >= totalUsers;
              return MatchCard(
                match: match,
                isTopPick: isTopPick,
                onTap: () => context.pushNamed(
                  AppRoute.movieDetail,
                  pathParameters: {'movieId': match.movieId.toString()},
                ),
              )
                  .animate(delay: ((index % 10) * 60).ms)
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.08, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _EmptyMatchesState extends StatelessWidget {
  const _EmptyMatchesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const Gap(AppSpacing.md),
            Text(
              'No matches yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(AppSpacing.xs),
            Text(
              'When two or more users save the same movie, it shows up here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
