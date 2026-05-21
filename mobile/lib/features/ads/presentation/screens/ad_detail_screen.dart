// lib/features/ads/presentation/screens/ad_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../../../ratings/data/rating_providers.dart';
import '../../../ratings/domain/rating_model.dart';
import '../../../ratings/presentation/widgets/rating_submit_sheet.dart';
import '../../../favorites/data/favorite_repository.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';
import '../widgets/contact_sheet.dart';
import '../widgets/sold_fee_sheet.dart';

// ── Related ads provider ──────────────────────────────────────────────────────

final relatedAdsProvider =
    FutureProvider.family<List<AdListModel>, ({int categoryId, int excludeId})>(
      (ref, params) async {
        final result = await ref
            .read(adRepositoryProvider)
            .getAds(AdsFilter(categoryId: params.categoryId, page: 1));
        return result.ads
            .where((a) => a.id != params.excludeId)
            .take(4)
            .toList();
      },
    );

// ── Entry ─────────────────────────────────────────────────────────────────────

class AdDetailScreen extends ConsumerStatefulWidget {
  final int adId;
  const AdDetailScreen({super.key, required this.adId});

  @override
  ConsumerState<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends ConsumerState<AdDetailScreen> {
  bool? _isFavorite;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final status = await ref
          .read(favoriteRepositoryProvider)
          .checkStatus(widget.adId);
      if (mounted) setState(() => _isFavorite = status);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final newStatus = await ref
          .read(favoriteRepositoryProvider)
          .toggleFavorite(widget.adId);
      ref.invalidate(favoritesListProvider);
      if (mounted) setState(() => _isFavorite = newStatus);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(adDetailProvider(widget.adId));

    return adState.when(
      data: (ad) => _HarajDetailScaffold(
        ad: ad,
        isFavorite: _isFavorite ?? false,
        onToggleFavorite: _toggleFavorite,
      ),
      loading: () => const _DetailSkeleton(),
      error: (err, _) => _ErrorScaffold(
        onRetry: () => ref.invalidate(adDetailProvider(widget.adId)),
      ),
    );
  }
}

// ── Full Haraj-Style Scaffold ─────────────────────────────────────────────────

class _HarajDetailScaffold extends ConsumerStatefulWidget {
  final AdDetailModel ad;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _HarajDetailScaffold({
    required this.ad,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  ConsumerState<_HarajDetailScaffold> createState() =>
      _HarajDetailScaffoldState();
}

class _HarajDetailScaffoldState extends ConsumerState<_HarajDetailScaffold> {
  final _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openContactSheet() {
    ContactSheet.show(
      context,
      adId: widget.ad.id,
      sellerName: widget.ad.user?.name ?? 'العارض',
      phone: widget.ad.contactPhone,
    );
  }

  void _openRatingSheet() {
    if (widget.ad.user == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RatingSubmitSheet(
        adId: widget.ad.id,
        sellerName: widget.ad.user!.name,
      ),
    ).then((submitted) {
      if (submitted == true) {
        ref.invalidate(adRatingsProvider(widget.ad.id));
        if (widget.ad.user != null) {
          ref.invalidate(userRatingSummaryProvider(widget.ad.user!.id));
        }
      }
    });
  }

  void _share() {
    final text = '${widget.ad.title}\n${widget.ad.priceDisplay}\nبرق واضح';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط الإعلان'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatMemberSince(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 30) return '${diff.inDays} يوم';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} شهر';
    final years = (diff.inDays / 365).floor();
    return years == 1 ? 'سنة' : '$years سنوات';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'الآن';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
    return 'قبل ${(diff.inDays / 30).floor()} شهر';
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),

        // ── AppBar ─────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: const Color(0xFF0075C4),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              textDirection: TextDirection.ltr,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _MoreOptionsDialog(
                  adId: ad.id,
                  sellerId: ad.user?.id,
                  adStatus: ad.status,
                ),
              ),
            ),
          ],
        ),

        // ── Body ───────────────────────────────────────────────────────
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Image Carousel
              _ImageCarousel(
                images: ad.images,
                controller: _pageController,
                currentIndex: _currentImageIndex,
                onPageChanged: (i) => setState(() => _currentImageIndex = i),
              ),

              // Title + Price + Meta
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF159787),
                        height: 1.4,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 10),

                    // Price row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ad.isFree
                                ? const Color(0xFF159787)
                                : const Color(0xFF0075C4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ad.priceDisplay,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (ad.isNegotiable) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: .4),
                              ),
                            ),
                            child: const Text(
                              'قابل للتفاوض',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Location + time + views
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (ad.city != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Color(0xFF0075C4),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                ad.city!.nameAr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.neutralGray600,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.neutralGray500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _timeAgo(ad.publishedAt ?? ad.createdAt),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.neutralGray600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: AppTheme.neutralGray500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${ad.viewsCount} مشاهدة',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.neutralGray600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Seller Row
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: InkWell(
                  onTap: ad.user == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          context.push('/users/${ad.user!.id}');
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            ad.user?.avatar != null &&
                                ad.user!.avatar!.isNotEmpty
                            ? NetworkImage(
                                AppConstants.normalizeImageUrl(
                                  ad.user!.avatar!,
                                ),
                              )
                            : null,
                        child:
                            ad.user?.avatar == null ||
                                (ad.user?.avatar?.isEmpty ?? true)
                            ? const Icon(
                                Icons.person,
                                size: 22,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ad.user?.name ?? 'غير معروف',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF0075C4),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (ad.user?.isVerified ?? false) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: Color(0xFF0075C4),
                                  ),
                                ],
                                if (ad.user?.isDealer ?? false) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF159787,
                                      ).withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'معرض',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF159787),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_left,
                                  size: 18,
                                  color: AppTheme.neutralGray500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${ad.user?.totalAdsCount ?? 0} إعلان · عضو منذ ${_formatMemberSince(ad.user?.memberSince)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.neutralGray500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if ((ad.user?.avgRating ?? 0) > 0) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Color(0xFFFFC107),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${ad.user!.avgRating!.toStringAsFixed(1)} (${ad.user!.ratingCount ?? 0})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.neutralGray600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0075C4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'الملف',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Field Values (category-specific attributes)
              if (ad.fieldValues.isNotEmpty)
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل الإعلان',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ad.fieldValues
                            .map((fv) => _FieldValueChip(fv))
                            .toList(),
                      ),
                    ],
                  ),
                ),

              // Description
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الوصف',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ad.description.isEmpty
                          ? 'لا يوجد وصف للإعلان.'
                          : ad.description,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.8,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),

              // Disclaimer
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFFFFF8E1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFF57F17),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'أخبرني أنك عن طريق تطبيق برق واضح إبراءً للذمة',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFF57F17),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contact Button
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                margin: const EdgeInsets.only(top: 2),
                child: InkWell(
                  onTap: _openContactSheet,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0075C4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'تواصل مع البائع',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.contact_phone,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Ratings & Reviews Section
              _RatingsSection(ad: ad, onWriteReview: _openRatingSheet),

              // Related Ads Section
              if (ad.category != null)
                _RelatedAdsSection(
                  categoryId: ad.category!.id,
                  categoryName: ad.category!.nameAr,
                  excludeId: ad.id,
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),

        // ── Bottom Navigation Bar ──────────────────────────────────────
        bottomNavigationBar: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BottomAction(
                  icon: Icons.arrow_back_ios_new,
                  onPress: () {
                    if (ad.id > 1) {
                      context.pushReplacement('/ads/${ad.id - 1}');
                    }
                  },
                ),
                _BottomAction(
                  icon: Icons.share,
                  label: 'مشاركة',
                  size: 28,
                  fontSize: 12,
                  onPress: _share,
                ),
                _BottomAction(
                  icon: Icons.contact_phone_outlined,
                  label: 'تواصل',
                  size: 30,
                  fontSize: 13,
                  onPress: _openContactSheet,
                ),
                _BottomAction(
                  icon: widget.isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: 'تفضيل',
                  onPress: widget.onToggleFavorite,
                  isActive: widget.isFavorite,
                ),
                _BottomAction(
                  icon: Icons.arrow_forward_ios,
                  onPress: () => context.pushReplacement('/ads/${ad.id + 1}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Image Carousel ────────────────────────────────────────────────────────────

class _ImageCarousel extends StatelessWidget {
  final List<AdImageModel> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _ImageCarousel({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 280,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // Swipeable pages
          PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: images.length,
            itemBuilder: (context, i) => CachedNetworkImage(
              imageUrl: AppConstants.normalizeImageUrl(images[i].imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),

          // Counter badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentIndex + 1} / ${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Dot indicators
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length > 8 ? 8 : images.length, (
                  i,
                ) {
                  final displayIndex = images.length > 8
                      ? currentIndex.clamp(0, 7)
                      : currentIndex;
                  final isActive = i == displayIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Field Value Chip ──────────────────────────────────────────────────────────

class _FieldValueChip extends StatelessWidget {
  final AdFieldValueModel field;
  const _FieldValueChip(this.field);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF0075C4).withValues(alpha: .2),
        ),
      ),
      child: RichText(
        textDirection: TextDirection.rtl,
        text: TextSpan(
          children: [
            TextSpan(
              text: '${field.labelAr}: ',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.neutralGray600,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: field.displayValue,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0075C4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ratings & Reviews Section ─────────────────────────────────────────────────

class _RatingsSection extends ConsumerWidget {
  final AdDetailModel ad;
  final VoidCallback onWriteReview;

  const _RatingsSection({required this.ad, required this.onWriteReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(adRatingsProvider(ad.id));

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC107),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'التقييمات والآراء',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                    ),
                    if ((ad.user?.ratingCount ?? 0) > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${ad.user!.ratingCount})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.neutralGray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Write review button
              if (ad.user != null)
                GestureDetector(
                  onTap: onWriteReview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0075C4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'اكتب تقييم',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Average rating summary
          if ((ad.user?.avgRating ?? 0) > 0) ...[
            _RatingSummaryRow(
              avgRating: ad.user!.avgRating!,
              ratingCount: ad.user!.ratingCount ?? 0,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],

          // Ratings list
          ratingsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Color(0xFF0075C4),
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'تعذر تحميل التقييمات',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(adRatingsProvider(ad.id)),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
            data: (ratings) {
              if (ratings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد تقييمات بعد\nكن أول من يقيّم هذا الإعلان',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: ratings
                    .take(3)
                    .map((r) => _RatingCard(rating: r))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Rating Summary Row ────────────────────────────────────────────────────────

class _RatingSummaryRow extends StatelessWidget {
  final double avgRating;
  final int ratingCount;
  const _RatingSummaryRow({required this.avgRating, required this.ratingCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          avgRating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0A1628),
            height: 1,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < avgRating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFFFC107),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$ratingCount تقييم',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.neutralGray500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Rating Card ───────────────────────────────────────────────────────────────

class _RatingCard extends StatelessWidget {
  final RatingModel rating;
  const _RatingCard({required this.rating});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()} شهر';
    return 'منذ ${(diff.inDays / 365).floor()} سنة';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF0075C4),
                backgroundImage: rating.rater.avatar != null
                    ? NetworkImage(
                        AppConstants.normalizeImageUrl(rating.rater.avatar!),
                      )
                    : null,
                child: rating.rater.avatar == null
                    ? Text(
                        rating.rater.name.isNotEmpty
                            ? rating.rater.name[0]
                            : '؟',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.rater.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                    Text(
                      _timeAgo(rating.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.neutralGray500,
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 15,
                    color: i < rating.stars
                        ? const Color(0xFFFFC107)
                        : Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),

          // Comment
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rating.comment!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Related Ads Section ───────────────────────────────────────────────────────

class _RelatedAdsSection extends ConsumerWidget {
  final int categoryId;
  final String categoryName;
  final int excludeId;

  const _RelatedAdsSection({
    required this.categoryId,
    required this.categoryName,
    required this.excludeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (categoryId: categoryId, excludeId: excludeId);
    final relatedAsync = ref.watch(relatedAdsProvider(params));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0075C4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'إعلانات مماثلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '#$categoryName',
                style: const TextStyle(
                  color: AppTheme.neutralGray500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          relatedAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Color(0xFF0075C4),
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (ads) {
              if (ads.isEmpty) return const SizedBox.shrink();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: ads.length,
                itemBuilder: (_, i) => _RelatedAdCard(ad: ads[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RelatedAdCard extends StatelessWidget {
  final AdListModel ad;
  const _RelatedAdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/ads/${ad.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: ad.primaryImage != null
                    ? CachedNetworkImage(
                        imageUrl: AppConstants.normalizeImageUrl(
                          ad.primaryImage!.thumbnailUrl,
                        ),
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutralGray800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ad.priceDisplay,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0075C4),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Action ─────────────────────────────────────────────────────────────

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPress;
  final bool isActive;
  final double size;
  final double fontSize;

  const _BottomAction({
    required this.icon,
    this.label,
    required this.onPress,
    this.isActive = false,
    this.size = 24,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.red : const Color(0xFF0075C4);
    return InkWell(
      onTap: onPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: size),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(
                label!,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: const Color(0xFF0075C4), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Container(
              height: 24,
              width: double.infinity,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 12),
            Container(height: 16, width: 120, color: Colors.grey[200]),
            const SizedBox(height: 20),
            Container(height: 14, width: 200, color: Colors.grey[200]),
          ],
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorScaffold({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF0075C4)),
      body: Center(
        child: ElevatedButton(
          onPressed: onRetry,
          child: const Text('إعادة المحاولة'),
        ),
      ),
    );
  }
}

// ── More Options Modal ────────────────────────────────────────────────────────

class _MoreOptionsDialog extends ConsumerStatefulWidget {
  final int adId;
  final int? sellerId;
  final String adStatus;

  const _MoreOptionsDialog({
    required this.adId,
    required this.sellerId,
    required this.adStatus,
  });

  @override
  ConsumerState<_MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class _MoreOptionsDialogState extends ConsumerState<_MoreOptionsDialog> {
  bool _markingSold = false;

  Future<void> _handleMarkSold() async {
    setState(() => _markingSold = true);
    try {
      final result = await ref.read(adRepositoryProvider).markSold(widget.adId);
      ref.invalidate(adDetailProvider(widget.adId));
      if (mounted) {
        Navigator.pop(context); // close the dialog
        await SoldFeeSheet.show(
          context,
          adTitle: result.title,
          adPrice: result.price,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _markingSold = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = currentUser != null && currentUser.id == widget.sellerId;
    final alreadySold = widget.adStatus == 'sold';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'خيارات إضافية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isOwner && !alreadySold) ...[
                _buildOption(
                  icon: Icons.sell_outlined,
                  label: 'تم البيع',
                  color: const Color(0xFF159787),
                  isLoading: _markingSold,
                  onTap: _handleMarkSold,
                ),
                const SizedBox(height: 16),
              ],
              _buildOption(
                icon: Icons.person_add_alt_1,
                label: 'متابعة البائع',
                color: const Color(0xFF0075C4),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت متابعة البائع بنجاح')),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildOption(
                icon: Icons.flag_outlined,
                label: 'الإبلاغ عن الإعلان',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ReportSheet(adId: widget.adId),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            if (!isLoading)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: color.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
