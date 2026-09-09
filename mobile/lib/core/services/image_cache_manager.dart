import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk-cache manager for all network images in the app.
///
/// Keeps immutable, content-addressed ad images for the same one-year lifetime
/// advertised by the CDN. The bounded object count prevents unbounded disk use.
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'barq_img_cache';

  static final AppImageCacheManager instance = AppImageCacheManager._();

  AppImageCacheManager._()
    : super(
        Config(
          _key,
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: _key),
          fileService: HttpFileService(),
        ),
      );
}
