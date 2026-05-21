import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';
import '../widgets/sold_fee_sheet.dart';

// ── Status config ─────────────────────────────────────────────────────────────

const _statusConfig = {
  'active': (label: 'نشط', color: Color(0xFF16A34A)),
  'sold': (label: 'مُباع', color: Color(0xFF2563EB)),
  'pending_review': (label: 'قيد المراجعة', color: Color(0xFFCA8A04)),
  'expired': (label: 'منتهي', color: Color(0xFFEA580C)),
  'rejected': (label: 'مرفوض', color: Color(0xFFDC2626)),
};

// ── Tab definitions ───────────────────────────────────────────────────────────

const _tabs = [
  (key: 'all', label: 'الكل'),
  (key: 'active', label: 'نشط'),
  (key: 'sold', label: 'مُباع'),
  (key: 'expired', label: 'منتهي'),
  (key: 'pending_review', label: 'قيد المراجعة'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class MyAdsScreen extends ConsumerStatefulWidget {
  const MyAdsScreen({super.key});

  @override
  ConsumerState<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends ConsumerState<MyAdsScreen> {
  String _activeTab = 'all';

  @override
  Widget build(BuildContext context) {
    final myAdsState = ref.watch(myAdsProvider);

    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text(
          'إعلاناتي',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            color: AppTheme.neutralGray600,
            onPressed: () => ref.read(myAdsProvider.notifier).refresh(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: myAdsState.when(
        data: (ads) {
          // Per-tab counts
          final counts = <String, int>{
            'all': ads.length,
            for (final t in _tabs.skip(1))
              t.key: ads.where((a) => a.status == t.key).length,
          };

          // Filtered list
          final filtered = _activeTab == 'all'
              ? ads
              : ads.where((a) => a.status == _activeTab).toList();

          return Column(
            children: [
              // ── Tab bar ──────────────────────────────────────────────────
              _StatusTabBar(
                activeTab: _activeTab,
                counts: counts,
                onTabChanged: (tab) => setState(() => _activeTab = tab),
              ),

              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        tab: _activeTab,
                        tabLabel: _tabs
                            .firstWhere((t) => t.key == _activeTab)
                            .label,
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(myAdsProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) =>
                              _AdListTile(ad: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => Column(
          children: [
            // Tab bar placeholder (shimmer feel)
            Container(
              height: 48,
              color: Colors.white,
              child: const Center(child: LinearProgressIndicator()),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const _SkeletonTile(),
              ),
            ),
          ],
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.neutralGray100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: AppTheme.neutralGray500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تعذّر تحميل الإعلانات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray900,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.read(myAdsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post-ad'),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'إعلان جديد',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
    );
  }
}

// ── Status tab bar ────────────────────────────────────────────────────────────

class _StatusTabBar extends StatelessWidget {
  final String activeTab;
  final Map<String, int> counts;
  final void Function(String) onTabChanged;

  const _StatusTabBar({
    required this.activeTab,
    required this.counts,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _tabs.length,
        itemBuilder: (context, i) {
          final tab = _tabs[i];
          final isActive = tab.key == activeTab;
          final count = counts[tab.key] ?? 0;

          return GestureDetector(
            onTap: () => onTabChanged(tab.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryBlue.withValues(alpha: .1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: isActive ? AppTheme.primaryBlue : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? AppTheme.primaryBlue
                          : AppTheme.neutralGray600,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryBlue
                            : AppTheme.neutralGray500,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Ad tile ───────────────────────────────────────────────────────────────────

class _AdListTile extends ConsumerStatefulWidget {
  final AdListModel ad;
  const _AdListTile({required this.ad});

  @override
  ConsumerState<_AdListTile> createState() => _AdListTileState();
}

class _AdListTileState extends ConsumerState<_AdListTile> {
  bool _deletingAd = false;
  bool _markingSold = false;

  AdListModel get ad => widget.ad;

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'حذف الإعلان',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'هل أنت متأكد من حذف هذا الإعلان؟ لا يمكن التراجع.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deletingAd = true);
    try {
      await ref.read(adRepositoryProvider).deleteAd(ad.id);
      ref.read(myAdsProvider.notifier).removeLocally(ad.id);
      ref.invalidate(adsFeedProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingAd = false);
    }
  }

  Future<void> _handleMarkSold() async {
    setState(() => _markingSold = true);
    try {
      await ref.read(adRepositoryProvider).markSold(ad.id);
      ref.read(myAdsProvider.notifier).updateStatus(ad.id, 'sold', 'مُباع');
      if (mounted) {
        await SoldFeeSheet.show(context, adTitle: ad.title, adPrice: ad.price);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _markingSold = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc =
        _statusConfig[ad.status] ??
        (label: ad.statusLabel, color: AppTheme.neutralGray500);
    final daysRemaining = _daysUntilExpiry(ad.expiresAt);
    final isExpiringSoon =
        daysRemaining != null &&
        daysRemaining <= 5 &&
        daysRemaining >= 0 &&
        ad.status == 'active';
    final isActive = ad.status == 'active';

    return Opacity(
      opacity: _deletingAd ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => context.push('/ads/${ad.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // ── Top section: image + info ───────────────────────────
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: ad.primaryImage != null
                            ? Image.network(
                                ad.primaryImage!.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _ImageFallback(icon: ad.category?.icon),
                              )
                            : _ImageFallback(icon: ad.category?.icon),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status badge + date
                          Row(
                            children: [
                              _StatusBadge(label: sc.label, color: sc.color),
                              const Spacer(),
                              Text(
                                _formatDate(ad.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.neutralGray400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Title
                          Text(
                            ad.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.neutralGray900,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Price
                          Text(
                            ad.priceDisplay,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expiry warning ──────────────────────────────────────
              if (isExpiringSoon)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        daysRemaining == 0
                            ? 'ينتهي الإعلان اليوم!'
                            : 'ينتهي خلال $daysRemaining ${daysRemaining == 1 ? "يوم" : "أيام"}',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Divider ─────────────────────────────────────────────
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // ── Action bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Mark sold — active ads only
                    if (isActive) ...[
                      _TileAction(
                        label: 'تم البيع',
                        icon: Icons.sell_outlined,
                        color: const Color(0xFF2563EB),
                        isLoading: _markingSold,
                        onTap: _handleMarkSold,
                      ),
                      const SizedBox(width: 8),
                    ],

                    const Spacer(),

                    // Delete — always shown
                    _TileAction(
                      label: 'حذف',
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFDC2626),
                      isLoading: _deletingAd,
                      isDestructive: true,
                      onTap: _handleDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int? _daysUntilExpiry(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return null;
    return diff.inDays;
  }

  static String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── Tile action button ────────────────────────────────────────────────────────

class _TileAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isDestructive;

  const _TileAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isDestructive
              ? color.withValues(alpha: .07)
              : color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Image fallback ────────────────────────────────────────────────────────────

class _ImageFallback extends StatelessWidget {
  final String? icon;
  const _ImageFallback({this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.neutralGray100,
      child: Center(
        child: Text(icon ?? '📦', style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String tab;
  final String tabLabel;
  const _EmptyState({required this.tab, required this.tabLabel});

  @override
  Widget build(BuildContext context) {
    final isAll = tab == 'all';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAll ? '📋' : '🔍', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              isAll
                  ? 'لا توجد إعلانات بعد'
                  : 'لا توجد إعلانات بحالة "$tabLabel"',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralGray900,
              ),
              textAlign: TextAlign.center,
            ),
            if (isAll) ...[
              const SizedBox(height: 8),
              Text(
                'انشر إعلانك الأول الآن!',
                style: TextStyle(color: AppTheme.neutralGray500),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push('/post-ad'),
                icon: const Icon(Icons.add),
                label: const Text('نشر إعلان'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Skeleton tile ─────────────────────────────────────────────────────────────

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 70,
              color: AppTheme.neutralGray100,
              margin: const EdgeInsets.only(right: 12),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 60,
                    color: AppTheme.neutralGray100,
                  ),
                  const SizedBox(height: 8),
                  Container(height: 14, color: AppTheme.neutralGray100),
                  const SizedBox(height: 6),
                  Container(
                    height: 14,
                    width: 80,
                    color: AppTheme.neutralGray100,
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
