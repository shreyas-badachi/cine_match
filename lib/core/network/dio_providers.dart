import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_endpoints.dart';
import 'network_status.dart';
import 'retry_interceptor.dart';

Dio _buildClient({
  required Ref ref,
  required String baseUrl,
  required Map<String, String> headers,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: headers,
    ),
  );

  // Order matters: the LogInterceptor below RetryInterceptor would only see
  // the final outcome. With it above, every attempt (including retries) is
  // logged — which is exactly what we want during the bad-connection test.
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ),
    );
  }

  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      onRetryStart: (attempt) =>
          ref.read(networkStatusProvider.notifier).startRetry(attempt),
      onRetryEnd: () => ref.read(networkStatusProvider.notifier).clear(),
    ),
  );

  return dio;
}

final reqresClientProvider = Provider<Dio>((ref) {
  return _buildClient(
    ref: ref,
    baseUrl: ApiEndpoints.reqresBaseUrl,
    headers: {
      'x-api-key': dotenv.env['REQRES_API_KEY'] ?? '',
      'Accept': 'application/json',
    },
  );
});

final tmdbClientProvider = Provider<Dio>((ref) {
  return _buildClient(
    ref: ref,
    baseUrl: ApiEndpoints.tmdbBaseUrl,
    headers: {
      // v4 Bearer token — keeps keys out of URL/query strings (and screenshots).
      'Authorization': 'Bearer ${dotenv.env['TMDB_BEARER_TOKEN'] ?? ''}',
      'Accept': 'application/json',
    },
  );
});

final omdbClientProvider = Provider<Dio>((ref) {
  // OMDB uses query-param auth, not headers. The repository will append
  // `?apikey=...` per request rather than setting it on the client.
  return _buildClient(
    ref: ref,
    baseUrl: ApiEndpoints.omdbBaseUrl,
    headers: {'Accept': 'application/json'},
  );
});
