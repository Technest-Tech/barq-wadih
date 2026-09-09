// lib/features/ads/presentation/screens/ad_detail_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/marketing_tracking_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../../../questions/presentation/widgets/ad_comments_section.dart';
import '../../../favorites/data/favorite_repository.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';
import '../widgets/contact_sheet.dart';
import '../widgets/ad_image_gallery.dart';
import '../widgets/dealer_vehicle_commission_notice.dart';
import '../widgets/sold_fee_sheet.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../core/widgets/riyal_text.dart';

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
  final AdImageModel? previewImage;

  const AdDetailScreen({super.key, required this.adId, this.previewImage});

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
      if (newStatus) {
        unawaited(
          ref
              .read(marketingTrackingProvider)
              .track(
                MarketingEvent.addToWishlist,
                properties: {
                  'content_id': widget.adId.toString(),
                  'content_type': 'product',
                },
              ),
        );
      }
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
      loading: () =>
          _DetailSkeleton(adId: widget.adId, previewImage: widget.previewImage),
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
  @override
  void initState() {
    super.initState();
    // Warm the next stacked photo while recording the detail view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(marketingTrackingProvider)
            .track(
              MarketingEvent.viewContent,
              properties: {
                'content_id': widget.ad.id.toString(),
                'content_name': widget.ad.title,
                if (widget.ad.category != null)
                  'content_category': widget.ad.category!.nameAr,
                'content_type': 'product',
                if (widget.ad.price != null) 'value': widget.ad.price,
                if (widget.ad.price != null) 'currency': 'SAR',
              },
            ),
      );
      if (widget.ad.images.length < 2) return;
      unawaited(
        precacheAppImage(
          context,
          widget.ad.images[1].imageUrl,
          memCacheWidth: 1280,
        ).catchError((_) {}),
      );
    });
  }

  void _openContactSheet() {
    ContactSheet.show(
      context,
      adId: widget.ad.id,
      sellerName: widget.ad.user?.name ?? 'العارض',
      phone: widget.ad.contactPhone,
    );
  }

  Future<void> _share() async {
    final link = AppConstants.adWebUrl(widget.ad.id);
    final text =
        '${widget.ad.title}\n${widget.ad.priceDisplay}\n$link\nبرق واضح';

    // iPad needs an anchor rect for the share popover.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await Share.share(
        text,
        subject: widget.ad.title,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      // No share targets available — fall back to the clipboard.
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ رابط الإعلان'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
              AdImageGallery(adId: ad.id, images: ad.images),

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
                          child: RiyalText(
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
                              color: Colors.red.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: .4),
                              ),
                            ),
                            child: const Text(
                              'على السوم',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
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

              if (ad.isVehicleCategory && (ad.user?.isDealer ?? false))
                const DealerVehicleCommissionNotice(),

              // Disclaimer
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFFFFEBEE),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFD32F2F),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'أخبرني أنك عن طريق تطبيق برق واضح إبراءً للذمة',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD32F2F),
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

              // Comments Section
              AdCommentsSection(adId: ad.id, sellerId: ad.user?.id),

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
          // Keep the 70pt action area above the home indicator. A fixed 70pt
          // total height left only ~36pt for the row on Face ID devices,
          // clipping the icon labels and triggering a RenderFlex overflow.
          height: 70 + MediaQuery.paddingOf(context).bottom,
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
      onTapDown: (_) {
        final image = ad.primaryImage;
        if (image != null) {
          unawaited(
            precacheAppImage(
              context,
              image.imageUrl,
              memCacheWidth: 1280,
            ).catchError((_) {}),
          );
        }
      },
      onTap: () => context.push('/ads/${ad.id}', extra: ad),
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
                    ? AppCachedImage(
                        imageUrl: ad.primaryImage!.thumbnailUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 640,
                        errorWidget: Container(
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
                  RiyalText(
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
  final int adId;
  final AdImageModel? previewImage;

  const _DetailSkeleton({required this.adId, this.previewImage});

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
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Hero(
                tag: 'ad-image-$adId',
                child: previewImage == null
                    ? ColoredBox(color: Colors.grey[200]!)
                    : AppCachedImage(
                        imageUrl: previewImage!.imageUrl,
                        lowResolutionUrl: previewImage!.thumbnailUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 1280,
                      ),
              ),
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
      ref.read(myAdsProvider.notifier).replaceLocally(result);
      if (mounted) {
        Navigator.pop(context); // close the dialog
        final deferred = await SoldFeeSheet.show(
          context,
          adId: widget.adId,
          adTitle: result.title,
          commission: result.paymentAmount ?? 0,
        );
        if (deferred && mounted) showCommissionDeferredHint(context);
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
                    isScrollControlled: true,
                    useSafeArea: true,
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
