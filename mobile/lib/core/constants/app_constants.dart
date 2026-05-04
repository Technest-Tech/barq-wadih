// ignore_for_file: constant_identifier_names

abstract class AppConstants {
  AppConstants._();

  static const String appName = 'برق واضح';
  static const String appNameEn = 'Barq Wadih';

  // API
  // Physical device: use Mac LAN IP (run: ipconfig getifaddr en0 to get yours)
  // Emulator:        use 10.0.2.2 instead
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.45:8080/api', // Mac LAN IP for physical device
  );
  static const String apiVersion = 'v1';

  // Storage keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserData = 'user_data';
  static const String keyLocale = 'locale';
  static const String keyTheme = 'theme';

  // Pagination
  static const int defaultPageSize = 20;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animBase = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);

  // Supported locales
  static const List<String> supportedLocales = ['ar', 'en'];

  // Helper to map backend localhost image URLs to the mobile API host
  static String normalizeImageUrl(String url) {
    if (url.startsWith('http://localhost:8080') || url.startsWith('http://127.0.0.1:8080')) {
      final baseHost = apiBaseUrl.replaceAll('/api', '');
      return url
          .replaceFirst('http://localhost:8080', baseHost)
          .replaceFirst('http://127.0.0.1:8080', baseHost);
    }
    return url;
  }
}
