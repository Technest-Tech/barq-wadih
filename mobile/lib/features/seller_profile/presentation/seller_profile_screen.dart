// lib/features/seller_profile/presentation/seller_profile_screen.dart
//
// Haraj-style seller profile page.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ads/domain/ad_model.dart';
import '../../ads/presentation/widgets/ad_card.dart';
import '../data/seller_profile_api.dart';
import '../domain/seller_profile_model.dart';

class SellerProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  const SellerProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<SellerProfileScreen> createState() =>
      _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(sellerProfileProvider(widget.userId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
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
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'ملف البائع',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: 'برق واضح — ملف البائع #${widget.userId}',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ رابط البائع'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        body: profileState.when(
          data: (profile) => _ProfileBody(
            profile: profile,
            tabController: _tabController,
            userId: widget.userId,
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF0075C4)),
          ),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('تعذر تحميل ملف البائع'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(sellerProfileProvider(widget.userId)),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final SellerProfileModel profile;
  final TabController tabController;
  final int userId;
  const _ProfileBody({
    required this.profile,
    required this.tabController,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _Header(profile: profile)),
        SliverToBoxAdapter(child: _StatsRow(profile: profile)),
        SliverToBoxAdapter(child: _RatingSummary(profile: profile)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: tabController,
              labelColor: const Color(0xFF0075C4),
              unselectedLabelColor: AppTheme.neutralGray500,
              indicatorColor: const Color(0xFF0075C4),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Colors.white,
              ),
              tabs: [
                Tab(text: 'الإعلانات (${profile.activeAdsCount})'),
                Tab(text: 'التقييمات (${profile.ratingCount})'),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          _SellerAdsTab(userId: userId),
          _SellerReviewsTab(userId: userId),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final SellerProfileModel profile;
  const _Header({required this.profile});

  String _memberSinceText() {
    if (profile.memberSince == null) return '—';
    final dt = profile.memberSince!;
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomLeft,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.neutralGray200,
                backgroundImage:
                    profile.avatar != null && profile.avatar!.isNotEmpty
                    ? CachedNetworkImageProvider(
                        AppConstants.normalizeImageUrl(profile.avatar!),
                      )
                    : null,
                child: profile.avatar == null || profile.avatar!.isEmpty
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              if (profile.isVerified)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF0075C4),
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.neutralGray900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'عضو منذ ${_memberSinceText()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray500,
                ),
              ),
            ],
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              profile.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.neutralGray700,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final SellerProfileModel profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          _StatCell(label: 'إعلان نشط', value: '${profile.activeAdsCount}'),
          _Divider(),
          _StatCell(label: 'تم بيعه', value: '${profile.soldAdsCount}'),
          _Divider(),
          _StatCell(label: 'تقييم', value: '${profile.ratingCount}'),
          _Divider(),
          _StatCell(
            label: 'متوسط',
            value: profile.avgRating.toStringAsFixed(1),
            suffix: '★',
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  const _StatCell({required this.label, required this.value, this.suffix});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.neutralGray900,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 2),
                Text(
                  suffix!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFFC107),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.neutralGray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppTheme.neutralGray200);
}

// ── Rating summary ─────────────────────────────────────────────────────────────

class _RatingSummary extends StatelessWidget {
  final SellerProfileModel profile;
  const _RatingSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.ratingCount == 0) return const SizedBox.shrink();
    final maxCount = profile.ratingDistribution.values.fold<int>(
      0,
      (a, b) => b > a ? b : a,
    );
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'توزيع التقييمات',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.neutralGray800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final star in [5, 4, 3, 2, 1])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '$star',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.neutralGray700,
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Color(0xFFFFC107),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: maxCount == 0
                            ? 0
                            : (profile.ratingDistribution[star] ?? 0) /
                                  maxCount,
                        backgroundColor: AppTheme.neutralGray100,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFFC107),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${profile.ratingDistribution[star] ?? 0}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.neutralGray500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── TabBar pinning ─────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 2;
  @override
  double get maxExtent => tabBar.preferredSize.height + 2;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

// ── Ads tab ────────────────────────────────────────────────────────────────────

class _SellerAdsTab extends ConsumerWidget {
  final int userId;
  const _SellerAdsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsState = ref.watch(sellerAdsProvider(userId));
    return adsState.when(
      data: (data) {
        if (data.ads.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('لا توجد إعلانات نشطة لهذا البائع'),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24, top: 4),
          itemCount: data.ads.length,
          itemBuilder: (context, i) {
            final AdListModel ad = data.ads[i];
            return AdCard(
              ad: ad,
              isGrid: false,
              onTap: () => context.push('/ads/${ad.id}'),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0075C4)),
      ),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(sellerAdsProvider(userId)),
          child: const Text('إعادة المحاولة'),
        ),
      ),
    );
  }
}

// ── Reviews tab ────────────────────────────────────────────────────────────────

class _SellerReviewsTab extends ConsumerWidget {
  final int userId;
  const _SellerReviewsTab({required this.userId});

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'الآن';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
    return 'قبل ${(diff.inDays / 30).floor()} شهر';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsState = ref.watch(sellerReviewsProvider(userId));
    return reviewsState.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reviews_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('لا توجد تقييمات بعد'),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = reviews[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.neutralGray200),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.neutralGray200,
                        backgroundImage:
                            r.rater.avatar != null && r.rater.avatar!.isNotEmpty
                            ? NetworkImage(
                                AppConstants.normalizeImageUrl(r.rater.avatar!),
                              )
                            : null,
                        child: r.rater.avatar == null || r.rater.avatar!.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.rater.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.neutralGray900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (idx) => Icon(
                                    idx < r.stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 14,
                                    color: const Color(0xFFFFC107),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _timeAgo(r.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.neutralGray500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (r.comment != null && r.comment!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      r.comment!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutralGray800,
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (r.ad != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => context.push('/ads/${r.ad!.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0075C4).withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tag,
                              size: 12,
                              color: Color(0xFF0075C4),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                r.ad!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0075C4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0075C4)),
      ),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(sellerReviewsProvider(userId)),
          child: const Text('إعادة المحاولة'),
        ),
      ),
    );
  }
}
