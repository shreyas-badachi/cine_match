import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cine_match/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel: tells the adapter to simulate a connection failure on this call.
/// We use a sentinel rather than a pre-built DioException because the
/// RequestOptions on a pre-built exception would be stale — the retry
/// interceptor relies on `extra[_retry_attempt]` from the *current* request.
const _fail = _ConnectionFailure();

class _ConnectionFailure {
  const _ConnectionFailure();
}

/// Scripted HTTP adapter — returns a sequence of responses or failures so we
/// can deterministically test the retry interceptor without hitting a real
/// network or mocking Dio internals.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._script);

  /// Each entry is either an int (HTTP status code) or `_fail` (network error).
  final List<Object> _script;
  int _index = 0;
  int get callCount => _index;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (_index >= _script.length) {
      throw StateError('Adapter exhausted at call ${_index + 1}');
    }
    final entry = _script[_index++];
    if (entry is _ConnectionFailure) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Simulated network failure',
      );
    }
    final status = entry as int;
    final bytes = utf8.encode('{"status":$status}');
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late int retryStartCalls;
  late int retryEndCalls;
  late _ScriptedAdapter adapter;

  setUp(() {
    retryStartCalls = 0;
    retryEndCalls = 0;
  });

  Dio buildDio(List<Object> script, {int maxRetries = 3}) {
    adapter = _ScriptedAdapter(script);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    // Self-reference is intentional: the interceptor calls dio.fetch() to
    // re-run the request, which goes through this same interceptor with an
    // incremented attempt counter.
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        maxRetries: maxRetries,
        // 1ms keeps tests fast; the algorithm is the same.
        initialDelay: const Duration(milliseconds: 1),
        onRetryStart: (_) => retryStartCalls++,
        onRetryEnd: () => retryEndCalls++,
      ),
    );
    return dio;
  }

  test('connection error retries until success', () async {
    final dio = buildDio([_fail, _fail, 200]);

    final response = await dio.get<dynamic>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 3);
    expect(retryStartCalls, 2);
    expect(retryEndCalls, greaterThanOrEqualTo(1));
  });

  test('5xx response is retried', () async {
    final dio = buildDio([503, 502, 200]);

    final response = await dio.get<dynamic>('/x');

    expect(response.statusCode, 200);
    expect(adapter.callCount, 3);
    expect(retryStartCalls, 2);
  });

  test('4xx response is NOT retried', () async {
    final dio = buildDio([404]);

    await expectLater(
      () => dio.get<dynamic>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.callCount, 1);
    expect(retryStartCalls, 0);
    expect(retryEndCalls, 0);
  });

  test('gives up after maxRetries and reports retry-end', () async {
    final dio = buildDio(
      [_fail, _fail, _fail, _fail],
      maxRetries: 3,
    );

    await expectLater(
      () => dio.get<dynamic>('/x'),
      throwsA(isA<DioException>()),
    );
    // Initial call + 3 retries = 4 attempts.
    expect(adapter.callCount, 4);
    expect(retryStartCalls, 3);
    expect(retryEndCalls, greaterThanOrEqualTo(1));
  });
}
