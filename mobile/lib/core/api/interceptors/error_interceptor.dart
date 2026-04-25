import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api_exceptions.dart';

/// Maps Dio errors to typed [ApiException] subclasses.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final responseData = err.response?.data;

    // Extract server error message if available
    String message = err.message ?? 'Unknown error';
    if (responseData is Map<String, dynamic>) {
      message = responseData['message'] as String? ?? message;
    }

    ApiException exception;

    switch (statusCode) {
      case 401:
        exception = UnauthorizedException(message);
      case 403:
        exception = ForbiddenException(message);
      case 404:
        exception = NotFoundException(message);
      case 422:
        final errors = <String, List<String>>{};
        if (responseData is Map<String, dynamic> &&
            responseData['errors'] is Map) {
          (responseData['errors'] as Map).forEach((key, value) {
            errors[key.toString()] = (value as List).map((e) => e.toString()).toList();
          });
        }
        exception = ValidationException(message, errors);
      case 429:
        exception = RateLimitException(message);
      case 500:
      case 502:
      case 503:
        exception = ServerException(message);
      default:
        if (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.sendTimeout) {
          exception = TimeoutException(message);
        } else if (err.type == DioExceptionType.connectionError) {
          exception = NetworkException(message);
        } else {
          exception = ApiException(message, statusCode);
        }
    }

    debugPrint('[ErrorInterceptor] ${exception.runtimeType}: $message (HTTP $statusCode)');

    handler.reject(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      error: exception,
      type: err.type,
    ));
  }
}
