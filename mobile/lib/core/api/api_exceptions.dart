/// Typed API exception hierarchy.
///
/// The [ErrorInterceptor] converts raw Dio errors into these for
/// clean handling in the presentation layer.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(message, 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([String message = 'Forbidden'])
      : super(message, 403);
}

class NotFoundException extends ApiException {
  const NotFoundException([String message = 'Not found'])
      : super(message, 404);
}

class ValidationException extends ApiException {
  final Map<String, List<String>> errors;

  const ValidationException(
    [String message = 'Validation failed',
    this.errors = const {}]
  ) : super(message, 422);

  /// Get first error for a given field
  String? fieldError(String field) => errors[field]?.first;
}

class RateLimitException extends ApiException {
  const RateLimitException([String message = 'Too many requests'])
      : super(message, 429);
}

class ServerException extends ApiException {
  const ServerException([String message = 'Server error'])
      : super(message, 500);
}

class NetworkException extends ApiException {
  const NetworkException([String message = 'Network error'])
      : super(message);
}

class TimeoutException extends ApiException {
  const TimeoutException([String message = 'Request timed out'])
      : super(message);
}
