import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/users/data/datasources/users_remote_datasource.dart';
import '../database/app_database.dart';
import '../network/api_endpoints.dart';
import '../network/retry_interceptor.dart';
import 'sync_service.dart';

const syncPendingUsersTask = 'sync_pending_users';

/// Top-level entry point for WorkManager. WorkManager spawns a separate
/// isolate to run background tasks, so this function cannot use any Riverpod
/// container or singleton from the main isolate — it sets up its own DB and
/// HTTP client from scratch.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != syncPendingUsersTask) return false;

    WidgetsFlutterBinding.ensureInitialized();

    AppDatabase? db;
    try {
      await dotenv.load(fileName: '.env');

      db = AppDatabase();

      final dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.reqresBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'x-api-key': dotenv.env['REQRES_API_KEY'] ?? '',
            'Accept': 'application/json',
          },
        ),
      );
      dio.interceptors.add(RetryInterceptor(dio: dio));

      final syncService = SyncService(
        usersDao: db.usersDao,
        remote: UsersRemoteDataSource(dio),
      );

      final result = await syncService.syncPendingUsers();
      // Returning false signals WorkManager to retry with backoff. Returning
      // true marks the task complete even if some rows still need attention —
      // the foreground SyncScheduler will pick them up the next time the app
      // gains connectivity.
      return result.isComplete;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('WorkManager sync failed: $e\n$st');
      }
      return false;
    } finally {
      await db?.close();
    }
  });
}

Future<void> initializeWorkManager() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('WorkManager initialize failed (likely iOS or test): $e\n$st');
    }
  }
}

/// Schedules a one-off sync task with a CONNECTED constraint. The OS will
/// run it as soon as connectivity is available. iOS execution is best-effort
/// per Apple's background-task restrictions.
Future<void> scheduleSyncOnConnectivity() async {
  try {
    await Workmanager().registerOneOffTask(
      syncPendingUsersTask,
      syncPendingUsersTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('WorkManager schedule failed: $e');
    }
  }
}
