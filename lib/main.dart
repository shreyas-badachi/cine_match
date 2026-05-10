import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_scheduler.dart';
import 'core/sync/workmanager_callback.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/reconnecting_banner.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeWorkManager();

  // Build the container manually so we can eagerly read syncSchedulerProvider —
  // this starts the connectivity listener before the first frame paints.
  // Widget tests pump CineMatchApp inside a fresh ProviderScope, so they never
  // construct this scheduler and don't need a real connectivity plugin.
  final container = ProviderContainer();
  container.read(syncSchedulerProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CineMatchApp(),
    ),
  );
}

class CineMatchApp extends StatelessWidget {
  const CineMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cine Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.config,
      // Overlays the "Reconnecting…" chip on every page. Sits in a Stack
      // above the page content so it never pushes layout when toggled.
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const ReconnectingBanner(),
          ],
        );
      },
    );
  }
}
