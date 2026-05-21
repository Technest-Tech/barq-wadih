// lib/features/ads/presentation/widgets/image_carousel.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../domain/ad_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/image_cache_manager.dart';

class ImageCarousel extends StatefulWidget {
  final List<AdImageModel> images;
  final double height;

  const ImageCarousel({super.key, required this.images, this.height = 300});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: widget.height,
        color: AppTheme.neutralGray100,
        child: const Center(child: Text('📦', style: TextStyle(fontSize: 64))),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Main PageView ─────────────────────────────────────────────────
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) {
            setState(() => _current = i);
            // Prefetch the next image so it's ready before the user swipes to it.
            final next = i + 1;
            if (next < widget.images.length) {
              precacheImage(
                CachedNetworkImageProvider(
                  AppConstants.normalizeImageUrl(widget.images[next].imageUrl),
                  cacheManager: AppImageCacheManager.instance,
                ),
                context,
              );
            }
          },
          itemBuilder: (context, i) {
            return CachedNetworkImage(
              imageUrl: AppConstants.normalizeImageUrl(
                widget.images[i].imageUrl,
              ),
              cacheManager: AppImageCacheManager.instance,
              fit: BoxFit.cover,
              memCacheWidth: 900,
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor: AppTheme.neutralGray200,
                highlightColor: const Color(0xFFF5F5F5),
                child: Container(color: Colors.white),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.neutralGray100,
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),

        if (widget.images.length > 1) ...[
          // ── Bottom Gradient ─────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x88000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Overlays (Thumbnails + Dots) ────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnails
                SizedBox(
                  height: 54,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.images.length,
                    itemBuilder: (context, i) {
                      final isActive = _current == i;
                      return GestureDetector(
                        onTap: () => _controller.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 54,
                          height: 54,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              if (isActive)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .3),
                                  blurRadius: 4,
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: AppConstants.normalizeImageUrl(
                                widget.images[i].thumbnailUrl,
                              ),
                              cacheManager: AppImageCacheManager.instance,
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: AppTheme.neutralGray200,
                                highlightColor: const Color(0xFFF5F5F5),
                                child: Container(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) {
                    return GestureDetector(
                      onTap: () => _controller.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _current == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _current == i ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
