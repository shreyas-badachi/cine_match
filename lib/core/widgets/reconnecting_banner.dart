import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../network/network_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Subtle non-blocking signal that the retry interceptor is currently
/// re-issuing a failed request. Pinned to the bottom-center as a chip so
/// it never obscures content. Spec: "Show a small 'reconnecting…' bar
/// while a retry is in progress — not a blocking pop-up."
class ReconnectingBanner extends ConsumerWidget {
  const ReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: AppDuration.normal,
          child: status.isReconnecting
              ? Padding(
                  key: const ValueKey('reconnecting'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Center(child: _Chip(attempt: status.attempt)),
                )
              : const SizedBox.shrink(key: ValueKey('idle')),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.attempt});

  final int attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      color: AppColors.surfaceContainer,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const Gap(AppSpacing.xs),
            Text(
              'Reconnecting…  (attempt $attempt)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
