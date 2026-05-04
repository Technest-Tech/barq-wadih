// lib/features/ads/presentation/screens/ad_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';
import '../widgets/contact_sheet.dart';

// ── Entry ─────────────────────────────────────────────────────────────────────

class AdDetailScreen extends ConsumerStatefulWidget {
  final int adId;
  const AdDetailScreen({super.key, required this.adId});

  @override
  ConsumerState<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends ConsumerState<AdDetailScreen> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(adDetailProvider(widget.adId));

    return adState.when(
      data: (ad) => _HarajDetailScaffold(
        ad: ad,
        isFavorite: _isFavorite,
        onToggleFavorite: () => setState(() => _isFavorite = !_isFavorite),
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
  ConsumerState<_HarajDetailScaffold> createState() => _HarajDetailScaffoldState();
}

class _HarajDetailScaffoldState extends ConsumerState<_HarajDetailScaffold> {
  void _openContactSheet() {
    ContactSheet.show(
      context,
      adId: widget.ad.id,
      sellerName: widget.ad.user?.name ?? 'العارض',
      phone: widget.ad.contactPhone,
    );
  }

  void _share() {
    final text = '${widget.ad.title}\n${widget.ad.priceDisplay}\nبرق واضح';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رابط الإعلان'), duration: Duration(seconds: 2)),
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
        backgroundColor: const Color(0xFFF8F9FA), // Slightly off-white background matching haraj
      
      // ── Haraj AppBar ───────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFF0075C4), // Haraj specific blue
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          // Force LTR direction so the arrow explicitly points Right (>)
          icon: const Icon(Icons.arrow_forward, color: Colors.white, textDirection: TextDirection.ltr), 
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _MoreOptionsDialog(adId: ad.id),
            ),
          ),
        ],
      ),

      // ── Main Content ────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF159787), // Haraj green/teal title color
                      height: 1.4,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),

                  // Meta Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF0075C4)),
                          const SizedBox(width: 4),
                          Text(
                            ad.city?.nameAr ?? '',
                            style: const TextStyle(fontSize: 14, color: AppTheme.neutralGray600),
                          ),
                        ],
                      ),
                      // Time
                      Row(
                        children: [
                          const Icon(Icons.sync, size: 14, color: AppTheme.neutralGray500),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo(ad.publishedAt ?? ad.createdAt),
                            style: const TextStyle(fontSize: 14, color: AppTheme.neutralGray600),
                          ),
                        ],
                      ),
                      // Rating
                      if (ad.user != null)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Color(0xFFFFC107)),
                            const SizedBox(width: 4),
                            Text(
                              '${((ad.user!.avgRating ?? 0)).toStringAsFixed(1)} (${ad.user!.ratingCount ?? 0} تقييم)',
                              style: const TextStyle(fontSize: 13, color: AppTheme.neutralGray600),
                            ),
                          ],
                        )
                      else
                        const SizedBox(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Seller Row — clickable, opens seller profile
                  InkWell(
                    onTap: ad.user == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            context.push('/users/${ad.user!.id}');
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Seller details
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: ad.user?.avatar != null && ad.user!.avatar!.isNotEmpty
                                      ? NetworkImage(AppConstants.normalizeImageUrl(ad.user!.avatar!))
                                      : null,
                                  child: ad.user?.avatar == null || (ad.user?.avatar?.isEmpty ?? true)
                                      ? const Icon(Icons.person, size: 20, color: Colors.grey)
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
                                            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0075C4)),
                                          ],
                                          if (ad.user?.isDealer ?? false) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF159787).withValues(alpha: .12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'معرض',
                                                style: TextStyle(fontSize: 10, color: Color(0xFF159787), fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 4),
                                          const Icon(Icons.chevron_left, size: 18, color: AppTheme.neutralGray500),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${ad.user?.totalAdsCount ?? 0} إعلان · عضو منذ ${_formatMemberSince(ad.user?.memberSince)}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Visit profile button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0075C4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'الملف',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Description Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 2), // small separator
              child: Text(
                ad.description.isEmpty ? 'لا يوجد وصف للإعلان.' : ad.description,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.neutralGray800,
                  height: 1.8,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),

            // Image Display
            Container(
              color: Colors.white,
              width: double.infinity,
              height: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ad.images.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: AppConstants.normalizeImageUrl(ad.images.first.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey[200]),
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image, size: 64, color: Colors.grey)),
                    )
                  else
                    Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image, size: 64, color: Colors.grey))),

                  if (ad.images.length > 1) ...[
                    // Dark Gradient at bottom of image
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      height: 80,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // "2 صورة أخرى" Pill
                    Positioned(
                      bottom: 16,
                      left: 0, right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B5998).withValues(alpha: .9), // Dark dusty blue
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${ad.images.length - 1} صورة أخرى',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Main Contact Button Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                      Text('تواصل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.contact_phone, color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ),

            // Comments Section (Mock UI)
            Container(
              color: const Color(0xFFF4F7FC), // Very light periwinkle/gray matching haraj comments bg
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Mock Comment 1
                  _buildMockComment('نواف--', '1 ش', 'التجهيز ايش. تصفيح ولا ايش'),
                  const SizedBox(height: 12),
                  // Mock Comment 2
                  _buildMockComment('allyly', '2025-10-15', 'ماشاء الله تبارك الله... شغل مرتب', isBlue: true),
                  const SizedBox(height: 16),
                  
                  // Comment Input
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF0075C4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(child: Text('أكتب تعليقك هنا...', style: TextStyle(color: Colors.grey[500], fontSize: 15))),
                        const SizedBox(width: 12),
                        const Icon(Icons.send, color: Color(0xFF0075C4)),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tags Section (Mock UI)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  _MockTag('#كاديلاك'),
                  _MockTag('#حراج السيارات'),
                  _MockTag('#اسكاليد 2025'),
                  _MockTag('#اسكاليد'),
                ],
              ),
            ),

            // Similar Ads Section (Mock UI)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 30),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0075C4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('متابعة العروض المماثلة', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        ad.category?.nameAr != null ? '#${ad.category!.nameAr}' : '#عروض_مماثلة',
                        style: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                    children: [
                         _MockSimilarAd('كبوت كاديلاك اسكاليد...', ad.images.isNotEmpty ? ad.images.first.imageUrl : null),
                         _MockSimilarAd('إسكاليد (Gen 5)...', ad.images.length > 1 ? ad.images[1].imageUrl : null),
                         _MockSimilarAd('كاديلاك اسكاليد 2...', ad.images.length > 2 ? ad.images[2].imageUrl : null),
                         _MockSimilarAd('سيارة اسكاليد مستعملة...', null),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Fixed Haraj Bottom Navigation Bar ─────────────────────────────────
      bottomNavigationBar: Container(
        height: 70, // Increased height for larger buttons
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous Ad (Right edge of screen in RTL, points >)
              _BottomAction(
                icon: Icons.arrow_back_ios_new, 
                onPress: () {
                  if (ad.id > 1) {
                    context.pushReplacement('/ads/${ad.id - 1}');
                  }
                },
              ), 
              // Enlarge Share button
              _BottomAction(
                icon: Icons.share, 
                label: 'مشاركة', 
                size: 28,
                fontSize: 12,
                onPress: _share,
              ),
              // Enlarge Contact button
              _BottomAction(
                icon: Icons.contact_phone_outlined, 
                label: 'تواصل', 
                size: 30, // Larger size
                fontSize: 13, // Larger font
                onPress: _openContactSheet,
              ),
              _BottomAction(
                icon: Icons.favorite_border, 
                label: 'تفضيل', 
                onPress: widget.onToggleFavorite, 
                isActive: widget.isFavorite,
              ),
              // Next Ad (Left edge of screen in RTL, points <)
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

  Widget _buildMockComment(String user, String time, String text, {bool isBlue = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 12, backgroundColor: Colors.grey[300], child: Icon(Icons.person, size: 14, color: isBlue ? const Color(0xFF0075C4) : Colors.grey)),
                  const SizedBox(width: 8),
                  Text(user, style: TextStyle(color: isBlue ? const Color(0xFF0075C4) : AppTheme.neutralGray800, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text(time, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, color: AppTheme.neutralGray800), textDirection: TextDirection.rtl),
        ],
      ),
    );
  }
}

class _MockTag extends StatelessWidget {
  final String label;
  const _MockTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200], // Changed from 100 to 200 to give it a bit more visibility since it has no white card behind it
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 11)), // Changed color and smaller text
    );
  }
}

class _MockSimilarAd extends StatelessWidget {
  final String title;
  final String? imageUrl;
  const _MockSimilarAd(this.title, this.imageUrl);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: imageUrl != null ? DecorationImage(image: NetworkImage(AppConstants.normalizeImageUrl(imageUrl!)), fit: BoxFit.cover) : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.neutralGray800), maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

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
              Text(label!, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600)),
            ]
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
             Container(height: 30, width: double.infinity, color: Colors.grey[200]),
             const SizedBox(height: 20),
             Container(height: 14, width: 120, color: Colors.grey[200]),
             const SizedBox(height: 40),
             Container(height: 200, width: double.infinity, color: Colors.grey[200]),
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
        child: ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ),
    );
  }
}

// ── Premium Options Modal ─────────────────────────────────────────────────────

class _MoreOptionsDialog extends StatelessWidget {
  final int adId;
  const _MoreOptionsDialog({required this.adId});

  @override
  Widget build(BuildContext context) {
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
                   const SizedBox(width: 48), // Spacer to balance the close button
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
                    builder: (_) => ReportSheet(adId: adId),
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
  }) {
    return InkWell(
      onTap: onTap,
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
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
