import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../routes/app_router.dart';
import '../providers/users_providers.dart';
import '../widgets/user_list_item.dart';
import '../widgets/user_list_skeleton.dart';
import '../widgets/users_empty_state.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Trigger the first page load after the initial frame so the widget
    // tree is fully built before any provider state changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(usersPaginationProvider.notifier).loadNextPage();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    // Load more once the user is within ~200px of the bottom.
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(usersPaginationProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);
    final pagination = ref.watch(usersPaginationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cine Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'Matches',
            onPressed: () => context.pushNamed(AppRoute.matches),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(usersPaginationProvider.notifier).refresh(),
        child: usersAsync.when(
          loading: () => const UsersListSkeleton(),
          error: (e, _) =>
              UsersEmptyState(errorMessage: 'Local database error: $e'),
          data: (users) => _UsersBody(
            users: users,
            pagination: pagination,
            scrollController: _scrollController,
            onRetry: () =>
                ref.read(usersPaginationProvider.notifier).loadNextPage(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add user',
        onPressed: () => context.pushNamed(AppRoute.addUser),
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

class _UsersBody extends StatelessWidget {
  const _UsersBody({
    required this.users,
    required this.pagination,
    required this.scrollController,
    required this.onRetry,
  });

  final List<dynamic> users;
  final UsersPaginationState pagination;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty && pagination.isLoading) {
      return const UsersListSkeleton();
    }

    if (users.isEmpty) {
      return UsersEmptyState(
        errorMessage: pagination.errorMessage,
        onRetry: onRetry,
      );
    }

    final showFooter = pagination.isLoading || pagination.hasError;
    final itemCount = users.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Gap(AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return pagination.hasError
              ? _PaginationErrorTile(onRetry: onRetry)
              : const UserListItemSkeleton();
        }
        final entry = users[index];
        return UserListItem(
          user: entry.user,
          savedCount: entry.savedCount,
          onTap: () => context.pushNamed(
            AppRoute.movies,
            pathParameters: {'userId': entry.user.id.toString()},
          ),
        )
            .animate(delay: (index * 60).ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.08, end: 0);
      },
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
