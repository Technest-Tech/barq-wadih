import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/banner_providers.dart';
import '../../domain/banner_model.dart';

/// Auto-sliding banner carousel that fetches banners by [position].
///
/// Shows a shimmer placeholder while loading, nothing if no banners exist.
class BannerCarousel extends ConsumerStatefulWidget {
  final String position;

  /// Auto-slide interval. Default: 5 seconds.
  final Duration interval;

  const BannerCarousel({
    super.key,
    required this.position,
    this.interval = const Duration(seconds: 5),
  });

  @override
  ConsumerState<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<BannerCarousel> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer(int totalPages) {
    _timer?.cancel();
    if (totalPages <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % totalPages;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index, int total) {
    setState(() => _currentPage = index);
    _startTimer(total); // Reset timer on manual swipe
  }

  Future<void> _handleTap(BannerModel banner) async {
    try {
      final repo = ref.read(bannerRepositoryProvider);
      final redirectUrl = await repo.trackClick(banner.id);

      if (redirectUrl == null || !mounted) return;

      if (redirectUrl.startsWith('/ads/')) {
        // Internal ad navigation — handle via your router
        // For now, we simply log. Replace with your navigation logic.
        debugPrint('Navigate to ad: $redirectUrl');
      } else {
        // External URL or WhatsApp
        final uri = Uri.parse(redirectUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Banner click error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider(widget.position));

    return bannersAsync.when(
      loading: () => _buildSkeleton(context),
      error: (_, __) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        // Start auto-slide on first build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startTimer(banners.length);
        });

        return _buildCarousel(context, banners);
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      height: 170,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, List<BannerModel> banners) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 170,
      child: Stack(
        children: [
          // ── Page view ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (idx) => _onPageChanged(idx, banners.length),
              itemBuilder: (context, index) {
                final banner = banners[index];
                return GestureDetector(
                  onTap: () => _handleTap(banner),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      CachedNetworkImage(
                        imageUrl: AppConstants.normalizeImageUrl(banner.imageUrlMobile ?? banner.imageUrl),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, size: 36),
                          ),
                        ),
                      ),

                      // Gradient overlay + title
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            banner.title,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      // Link badge
                      if (banner.linkType != 'none')
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _linkLabel(banner.linkType),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Dot indicators ────────────────────────────────────────────
          if (banners.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (idx) {
                  final isActive = idx == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive
                          ? const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  String _linkLabel(String linkType) {
    switch (linkType) {
      case 'ad':
        return '📋 عرض';
      case 'whatsapp':
        return '💬 واتساب';
      case 'url':
        return '🔗 رابط';
      default:
        return '';
    }
  }
}
