import 'package:dio/dio.dart';

/// Retries a failed request with exponential backoff.
///
/// Retry-worthy errors: connection failures, timeouts, and 5xx responses.
/// 4xx responses (auth, not found, validation) are returned immediately —
/// retrying them would just hammer a permanent error.
///
/// Backoff schedule with the defaults: 400ms → 800ms → 1600ms (3 retries).
/// Total worst-case extra latency before giving up: ~2.8 seconds.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 400),
    this.onRetryStart,
    this.onRetryEnd,
  });

  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;

  /// Called when a retry attempt is about to start. Provides the 1-indexed
  /// attempt number. Used by the UI to show a "reconnecting…" banner.
  final void Function(int attempt)? onRetryStart;

  /// Called when retrying ends — either by success or by exhausting attempts.
  /// Used by the UI to clear the "reconnecting…" banner.
  final void Function()? onRetryEnd;

  static const _attemptKey = '_retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

    if (!_isRetryable(err) || attempt >= maxRetries) {
      // Only fire the "end" event if we actually started retrying. Avoids
      // clearing a banner that was never shown.
      if (attempt > 0) onRetryEnd?.call();
      return handler.next(err);
    }

    final nextAttempt = attempt + 1;
    // Exponential: attempt 0 → 1× delay, attempt 1 → 2×, attempt 2 → 4×.
    final delay = initialDelay * (1 << attempt);

    onRetryStart?.call(nextAttempt);
    await Future<void>.delayed(delay);

    final next = err.requestOptions.copyWith(
      extra: {...err.requestOptions.extra, _attemptKey: nextAttempt},
    );

    try {
      final response = await dio.fetch<dynamic>(next);
      onRetryEnd?.call();
      handler.resolve(response);
    } on DioException catch (e) {
      // Inner retry chain already exhausted itself — just propagate.
      handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status >= 500 && status < 600;
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
        return false;
    }
  }
}
