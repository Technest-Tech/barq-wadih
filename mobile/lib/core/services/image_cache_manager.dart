import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk-cache manager for all network images in the app.
///
/// Doubles the default object limit (200 → 500) so ad thumbnails survive
/// long browsing sessions without being evicted and re-downloaded.
class AppImageCacheManager {
  static const _key = 'barq_img_cache';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: _key),
      fileService: HttpFileService(),
    ),
  );
}
