import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/image_cache_manager.dart';
import '../../domain/ad_model.dart';

/// Full-width photos in reading order, with no fixed height or cropping.
class AdImageGallery extends StatelessWidget {
  const AdImageGallery({
    super.key,
    required this.adId,
    required this.images,
    this.imageProviderBuilder,
  });
  final int adId;
  final List<AdImageModel> images;
  final ImageProvider Function(AdImageModel)? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    if (images.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < images.length; i++)
          Builder(
            builder: (context) {
              final provider = imageProviderBuilder?.call(images[i]);
              final photo = AdPhoto(image: images[i], provider: provider);
              void open() => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) =>
                      AdImageFullscreen(image: images[i], provider: provider),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    label: ar
                        ? 'فتح الصورة ${i + 1} بملء الشاشة'
                        : 'Open image ${i + 1} fullscreen',
                    child: GestureDetector(
                      onTap: open,
                      child: i == 0
                          ? Hero(tag: 'ad-image-$adId', child: photo)
                          : photo,
                    ),
                  ),
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        end: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ar
                                  ? 'الصورة ${i + 1} من ${images.length}'
                                  : 'Image ${i + 1} of ${images.length}',
                            ),
                          ),
                          IconButton(
                            onPressed: open,
                            tooltip: ar ? 'عرض بملء الشاشة' : 'View fullscreen',
                            icon: const Icon(Icons.fullscreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// Lets the decoded image determine height, including older ads with no metadata.
/// The optional provider also supports local images and deterministic previews.
class AdPhoto extends StatefulWidget {
  const AdPhoto({
    super.key,
    required this.image,
    this.provider,
    this.fullscreen = false,
  });
  final AdImageModel image;
  final ImageProvider? provider;
  final bool fullscreen;

  @override
  State<AdPhoto> createState() => _AdPhotoState();
}

class _AdPhotoState extends State<AdPhoto> {
  int _retry = 0;
  ImageProvider get _provider =>
      widget.provider ??
      CachedNetworkImageProvider(
        AppConstants.normalizeImageUrl(widget.image.imageUrl),
        cacheManager: AppImageCacheManager.instance,
        maxWidth: widget.fullscreen ? null : 1280,
      );

  Widget _placeholder(Widget child) {
    if (widget.fullscreen) return Center(child: child);
    final width = widget.image.width ?? 0;
    final height = widget.image.height ?? 0;
    return AspectRatio(
      aspectRatio: width > 0 && height > 0 ? width / height : 4 / 3,
      child: Center(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Image(
      key: ValueKey(_retry),
      image: _provider,
      width: double.infinity,
      height: widget.fullscreen ? double.infinity : null,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, synchronous) =>
          frame != null || synchronous
          ? child
          : _placeholder(
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (context, error, stack) => _placeholder(
        TextButton.icon(
          style: widget.fullscreen
              ? TextButton.styleFrom(foregroundColor: Colors.white)
              : null,
          onPressed: () async {
            await _provider.evict();
            if (mounted) setState(() => _retry++);
          },
          icon: const Icon(Icons.refresh),
          label: Text(
            ar
                ? 'تعذّر تحميل الصورة. إعادة المحاولة'
                : 'Image could not load. Retry',
          ),
        ),
      ),
    );
  }
}

class AdImageFullscreen extends StatefulWidget {
  const AdImageFullscreen({super.key, required this.image, this.provider});
  final AdImageModel image;
  final ImageProvider? provider;

  @override
  State<AdImageFullscreen> createState() => _AdImageFullscreenState();
}

class _AdImageFullscreenState extends State<AdImageFullscreen> {
  final _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double scale, [Offset? focal]) {
    scale = scale.clamp(1.0, 5.0);
    if (scale == 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    final point = focal ?? _viewport.center(Offset.zero);
    final scene = _transform.toScene(point);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (point.dx - scene.dx * scale)
            .clamp(_viewport.width * (1 - scale), 0)
            .toDouble(),
        (point.dy - scene.dy * scale)
            .clamp(_viewport.height * (1 - scale), 0)
            .toDouble(),
        0,
      );
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: ar ? 'إغلاق' : 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(ar ? 'عرض الصورة' : 'Photo'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewport = constraints.biggest;
            return GestureDetector(
              onDoubleTapDown: (details) =>
                  _doubleTapPosition = details.localPosition,
              onDoubleTap: () => _zoom(
                _transform.value.getMaxScaleOnAxis() > 1 ? 1 : 2.5,
                _doubleTapPosition,
              ),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                child: AdPhoto(
                  image: widget.image,
                  provider: widget.provider,
                  fullscreen: true,
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ValueListenableBuilder<Matrix4>(
          valueListenable: _transform,
          builder: (context, matrix, _) {
            final scale = matrix.getMaxScaleOnAxis();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  tooltip: ar ? 'تصغير' : 'Zoom out',
                  onPressed: scale <= 1 ? null : () => _zoom(scale / 1.5),
                  icon: const Icon(Icons.zoom_out),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _zoom(1),
                  child: Text(ar ? 'إعادة ضبط' : 'Reset'),
                ),
                IconButton(
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  tooltip: ar ? 'تكبير' : 'Zoom in',
                  onPressed: scale >= 5 ? null : () => _zoom(scale * 1.5),
                  icon: const Icon(Icons.zoom_in),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
