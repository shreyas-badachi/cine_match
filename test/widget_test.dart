import 'dart:convert';
import 'dart:typed_data';

import 'package:cine_match/core/database/app_database.dart';
import 'package:cine_match/core/database/database_provider.dart';
import 'package:cine_match/core/network/dio_providers.dart';
import 'package:cine_match/core/sync/connectivity_service.dart';
import 'package:cine_match/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skips the connectivity_plus platform channel entirely. Real
/// `Connectivity()` opens a native event channel that schedules
/// real-time timers the test framework cannot drain.
class _StubConnectivityService implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> watchOnline() => const Stream.empty();
}

/// Adapter that returns an empty success response for every call. Keeps
/// widget tests hermetic — no real network, no error retry paths to wait on.
class _EmptyApiAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final body = utf8.encode(
      '{"page":1,"per_page":6,"total":0,"total_pages":1,"data":[]}',
    );
    return ResponseBody.fromBytes(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _stubDio() {
  final dio = Dio();
  dio.httpClientAdapter = _EmptyApiAdapter();
  return dio;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: '');
  });

  testWidgets('app boots and renders Users page as initial route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          connectivityServiceProvider
              .overrideWith((_) => _StubConnectivityService()),
          reqresClientProvider.overrideWith((_) => _stubDio()),
          tmdbClientProvider.overrideWith((_) => _stubDio()),
          omdbClientProvider.overrideWith((_) => _stubDio()),
        ],
        child: const CineMatchApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cine Match'), findsOneWidget);
    expect(find.byTooltip('Add user'), findsOneWidget);
    expect(find.byTooltip('Matches'), findsOneWidget);

    // Unmount before test ends so Drift's stream-cleanup Timer (scheduled
    // by StreamQueryStore.markAsClosed during disposal) fires before the
    // test framework's pending-timer invariant check runs.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
