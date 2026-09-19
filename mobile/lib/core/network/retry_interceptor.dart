import 'dart:async';

import 'package:dio/dio.dart';

/// Retries short-lived failures for safe, read-only API requests.
///
/// Mobile networks frequently change towers or briefly lose connectivity. A
/// single dropped GET should not leave the categories, cities, or feed in an
/// error state for the rest of the session. Writes are deliberately excluded
/// so an ad or payment can never be submitted twice.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor(this.dio, {this.maxRetries = 2});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();
    final attempt = options.extra['retry_attempt'] as int? ?? 0;

    if ((method != 'GET' && method != 'HEAD') ||
        attempt >= maxRetries ||
        !_isTransient(err)) {
      handler.next(err);
      return;
    }

    options.extra['retry_attempt'] = attempt + 1;
    await Future<void>.delayed(
      Duration(milliseconds: attempt == 0 ? 350 : 900),
    );

    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isTransient(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    final status = error.response?.statusCode;
    return status == 408 ||
        status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504;
  }
}
