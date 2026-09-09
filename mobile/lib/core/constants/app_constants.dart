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
    defaultValue: 'https://api.barqwadih.com/api',
  );
  static const String apiVersion = 'v1';

  // Public website (used to build shareable ad links)
  static const String webBaseUrl = 'https://barqwadih.com';

  // Canonical shareable web URL for a single ad (Arabic locale).
  // Mirrors the Next.js route: /{locale}/ads/{id}
  static String adWebUrl(int id) => '$webBaseUrl/ar/ads/$id';

  // Canonical shareable web URL for a public profile.
  // Mirrors the Next.js route /@{handle}. Arabic is the default locale and
  // localePrefix is 'as-needed', so this one carries no /ar segment.
  static String profileWebUrl(String username) => '$webBaseUrl/@$username';

  // Host shown to the user in place of a full URL ("barqwadih.com/@ahmd").
  static String displayUrl(String url) =>
      url.replaceFirst(RegExp(r'^https?://'), '');

  // Message used when sharing the app itself from the share sheet.
  static const String appShareMessage =
      'حمّل تطبيق برق واضح — سوق الإعلانات المبوبة في السعودية\n$webBaseUrl';

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

  // Helper to map backend image URLs to a reachable host on the mobile device.
  // Handles: localhost/127.0.0.1 absolute URLs, and relative /storage/... paths.
  static String normalizeImageUrl(String url) {
    final baseHost = apiBaseUrl.replaceAll('/api', '');
    if (url.startsWith('http://localhost:8080') ||
        url.startsWith('http://127.0.0.1:8080')) {
      return url
          .replaceFirst('http://localhost:8080', baseHost)
          .replaceFirst('http://127.0.0.1:8080', baseHost);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final path = url.startsWith('/') ? url : '/$url';
      return '$baseHost$path';
    }
    return url;
  }
}
