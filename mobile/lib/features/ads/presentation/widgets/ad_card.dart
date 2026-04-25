// lib/features/ads/presentation/widgets/ad_card.dart
//
// Horizontal ad card — always light mode.
// Image on the end (left in RTL), details on start (right in RTL).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/ad_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class AdCard extends StatefulWidget {
  final AdListModel ad;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool isFavorited;
  final bool isGrid;

  const AdCard({
    super.key,
    required this.ad,
    required this.onTap,
    this.onFavorite,
    this.isFavorited = false,
    this.isGrid = false,
  });

  @override
  State<AdCard> createState() => _AdCardState();
}class _AdCardState extends State<AdCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _isPressed ? const Color(0xFFF0F4FF) : Colors.white,
        child: Container(
          decoration: BoxDecoration(
            border: widget.isGrid 
              ? Border.all(color: AppTheme.neutralGray200, width: 1)
              : const Border(bottom: BorderSide(color: AppTheme.neutralGray200, width: 1)),
            borderRadius: widget.isGrid ? BorderRadius.circular(12) : null,
          ),
          padding: widget.isGrid
            ? const EdgeInsets.all(8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: widget.isGrid ? null : 130,
          child: widget.isGrid
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: _buildImageSection(ad),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildTextSection(ad)),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTextSection(ad)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    height: double.infinity,
                    child: _buildImageSection(ad),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildTextSection(AdListModel ad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title — dark for readability
        Text(
          ad.title,
          maxLines: widget.isGrid ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutralGray900,
            height: 1.35,
          ),
        ),
        if (!widget.isGrid) const Spacer() else const SizedBox(height: 4),

        // Price — green like Haraj
        Text(
          ad.priceDisplay,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.colorSuccess,
          ),
        ),
        if (!widget.isGrid) const SizedBox(height: 6) else const SizedBox(height: 4),

        // Location + Time row
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.neutralGray500),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                ad.city?.nameAr ?? '',
                style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.neutralGray500),
            const SizedBox(width: 2),
            Text(
              _timeAgo(ad.publishedAt ?? ad.createdAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageSection(AdListModel ad) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.isGrid ? 8 : 10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'ad-image-${ad.id}',
            child: ad.primaryImage != null
                ? CachedNetworkImage(
                    imageUrl: AppConstants.normalizeImageUrl(ad.primaryImage!.thumbnailUrl),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppTheme.neutralGray100,
                    ),
                    errorWidget: (_, __, ___) => _ImagePlaceholder(icon: ad.category?.icon),
                  )
                : _ImagePlaceholder(icon: ad.category?.icon),
          ),
          // Boosted badge — amber gold top-left
          if (ad.isBoosted)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: AppTheme.accentGold,
                child: const Text(
                  '⚡ مميز',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          // Image count badge
          if (ad.imagesCount > 1)
            Positioned(
              bottom: 5, right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 9, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      '${ad.imagesCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          // Favorite button
          if (widget.onFavorite != null)
            Positioned(
              bottom: 5, left: 5,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onFavorite!();
                },
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 14,
                    color: widget.isFavorited ? Colors.red : AppTheme.neutralGray500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}';
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String? icon;
  const _ImagePlaceholder({this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.neutralGray100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon ?? '📦', style: const TextStyle(fontSize: 32)),
          ],
        ),
      ),
    );
  }
}
