import 'dart:ui';
import 'package:dio/dio.dart';

/// Injects Accept-Language header based on the current app locale.
class LocaleInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Use the platform's current locale
    final locale = PlatformDispatcher.instance.locale;
    final langCode = locale.languageCode; // 'ar' or 'en'

    options.headers['Accept-Language'] = langCode;
    options.headers['X-Locale'] = langCode;

    handler.next(options);
  }
}
