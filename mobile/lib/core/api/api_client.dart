/// Centralized API client with Dio — singleton with interceptors.
///
/// All feature-level data layers should use this client instead of
/// creating their own Dio instances.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'interceptors/auth_interceptor.dart';
import 'interceptors/locale_interceptor.dart';
import 'interceptors/error_interceptor.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
          baseUrl: _resolveBaseUrl(),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Register interceptors in order
    dio.interceptors.addAll([
      LocaleInterceptor(),
      AuthInterceptor(),
      ErrorInterceptor(),
      if (kDebugMode) LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (msg) => debugPrint('[API] $msg'),
      ),
    ]);
  }

  /// Singleton access
  factory ApiClient() {
    _instance ??= ApiClient._internal();
    return _instance!;
  }

  /// Reset instance (useful for tests or logout)
  static void reset() {
    _instance = null;
  }

  static String _resolveBaseUrl() {
    const envUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.barqwadih.com/api/v1',
    );
    return envUrl;
  }

  // ── Convenience methods ──────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) => dio.put<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) => dio.delete<T>(path, options: options);
}
