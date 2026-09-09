import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/image_cache_manager.dart';

/// The single network-image path used by ad surfaces.
///
/// When [lowResolutionUrl] is supplied it is painted first (normally from the
/// already-cached feed thumbnail), while the detail image loads transparently
/// above it. This avoids the white/grey flash previously shown between routes.
class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final String? lowResolutionUrl;

  /// Feed cards only need the thumbnail; fetch the original on preview failure.
  final bool preferPreview;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget? errorWidget;
  final Color backgroundColor;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.lowResolutionUrl,
    this.preferPreview = false,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorWidget,
    this.backgroundColor = const Color(0xFFE5E7EB),
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = AppConstants.normalizeImageUrl(imageUrl);
    final previewUrl = lowResolutionUrl == null
        ? null
        : AppConstants.normalizeImageUrl(lowResolutionUrl!);
    final hasDistinctPreview =
        previewUrl != null && previewUrl.isNotEmpty && previewUrl != fullUrl;

    if (!hasDistinctPreview) {
      return _cachedImage(
        fullUrl,
        placeholder: ColoredBox(color: backgroundColor),
        onError:
            errorWidget ??
            ColoredBox(
              color: backgroundColor,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
      );
    }

    if (preferPreview) {
      return _cachedImage(
        previewUrl,
        placeholder: ColoredBox(color: backgroundColor),
        onError: _cachedImage(
          fullUrl,
          placeholder: ColoredBox(color: backgroundColor),
          onError: errorWidget ?? ColoredBox(color: backgroundColor),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _cachedImage(
          previewUrl,
          placeholder: ColoredBox(color: backgroundColor),
          onError: errorWidget ?? ColoredBox(color: backgroundColor),
        ),
        _cachedImage(
          fullUrl,
          placeholder: const SizedBox.expand(),
          // Keep the usable preview visible if the full-size request fails.
          onError: const SizedBox.expand(),
        ),
      ],
    );
  }

  Widget _cachedImage(
    String url, {
    required Widget placeholder,
    required Widget onError,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppImageCacheManager.instance,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      // A short cross-fade hides decode boundaries without making a cached
      // image feel delayed.
      fadeInDuration: preferPreview
          ? Duration.zero
          : const Duration(milliseconds: 70),
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => onError,
    );
  }
}

/// Starts the immutable image request before route navigation completes.
Future<void> precacheAppImage(
  BuildContext context,
  String url, {
  int? memCacheWidth,
}) {
  return precacheImage(
    CachedNetworkImageProvider(
      AppConstants.normalizeImageUrl(url),
      cacheManager: AppImageCacheManager.instance,
      maxWidth: memCacheWidth,
    ),
    context,
  );
}
