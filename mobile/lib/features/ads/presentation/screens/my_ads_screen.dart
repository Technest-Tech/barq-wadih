import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';
import '../widgets/boost_confirm_sheet.dart';

// ── Status config ─────────────────────────────────────────────────────────────

const _statusConfig = {
  'active':         (label: 'نشط',          color: Color(0xFF16A34A)),
  'sold':           (label: 'مُباع',         color: Color(0xFF2563EB)),
  'pending_review': (label: 'قيد المراجعة', color: Color(0xFFCA8A04)),
  'expired':        (label: 'منتهي',         color: Color(0xFFEA580C)),
  'rejected':       (label: 'مرفوض',        color: Color(0xFFDC2626)),
};

// ── Tab definitions ───────────────────────────────────────────────────────────

const _tabs = [
  (key: 'all',           label: 'الكل'),
  (key: 'active',        label: 'نشط'),
  (key: 'sold',          label: 'مُباع'),
  (key: 'expired',       label: 'منتهي'),
  (key: 'pending_review',label: 'قيد المراجعة'),
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
        backgroundColor: Colors.white,
        title: const Text('إعلاناتي', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
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
            for (final t in _tabs.skip(1)) t.key: ads.where((a) => a.status == t.key).length,
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
                        tabLabel: _tabs.firstWhere((t) => t.key == _activeTab).label,
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(myAdsProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _AdListTile(ad: filtered[i]),
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
                  width: 72, height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.neutralGray100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 36, color: AppTheme.neutralGray500),
                ),
                const SizedBox(height: 16),
                const Text('تعذّر تحميل الإعلانات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.neutralGray900)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.read(myAdsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        label: const Text('إعلان جديد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
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
                      color: isActive ? AppTheme.primaryBlue : AppTheme.neutralGray600,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryBlue : AppTheme.neutralGray500,
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

class _AdListTile extends ConsumerWidget {
  final AdListModel ad;
  const _AdListTile({required this.ad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc  = _statusConfig[ad.status] ?? (label: ad.statusLabel, color: AppTheme.neutralGray500);
    final daysRemaining = _daysUntilExpiry(ad.expiresAt);
    final isExpiringSoon = daysRemaining != null && daysRemaining <= 5 && daysRemaining >= 0 && ad.status == 'active';

    Future<void> handleDelete() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حذف الإعلان'),
          content: const Text('هل أنت متأكد من حذف هذا الإعلان؟ لا يمكن التراجع.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await ref.read(adRepositoryProvider).deleteAd(ad.id);
        ref.read(myAdsProvider.notifier).removeLocally(ad.id);
        ref.invalidate(adsFeedProvider);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }

    Future<void> handleMarkSold() async {
      try {
        await ref.read(adRepositoryProvider).markSold(ad.id);
        ref.read(myAdsProvider.notifier).updateStatus(ad.id, 'sold', 'مُباع');
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }

    Future<void> handleBoost() async {
      bool loading = false;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => BoostConfirmSheet(
            adTitle: ad.title,
            isLoading: loading,
            onConfirm: () async {
              setSheetState(() => loading = true);
              try {
                await ref.read(adRepositoryProvider).boostAd(ad.id);
                ref.read(myAdsProvider.notifier).refresh();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم ترقية الإعلان بنجاح! ⚡'), backgroundColor: Colors.green),
                  );
                }
              } on ApiException catch (e) {
                setSheetState(() => loading = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ),
      );
    }

    Future<void> handleRefresh() async {
      try {
        await ref.read(adRepositoryProvider).refreshAd(ad.id);
        ref.read(myAdsProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الإعلان بنجاح! 🔄'), backgroundColor: Colors.green),
          );
        }
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/ads/${ad.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 80, height: 70,
                      child: ad.primaryImage != null
                          ? Image.network(ad.primaryImage!.thumbnailUrl, fit: BoxFit.cover)
                          : Container(
                              color: AppTheme.neutralGray100,
                              child: Center(child: Text(ad.category?.icon ?? '📦', style: const TextStyle(fontSize: 28))),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status + date row
                        Row(
                          children: [
                            _StatusBadge(label: sc.label, color: sc.color),
                            const Spacer(),
                            Text(
                              _formatDate(ad.createdAt),
                              style: TextStyle(fontSize: 11, color: AppTheme.neutralGray500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Title
                        Text(
                          ad.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 4),

                        // Price
                        Text(
                          ad.priceDisplay,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ),

                  // Actions column
                  Column(
                    children: [
                      if (ad.status == 'active') ...[
                        // Boost button — only if not currently boosted
                        if (!ad.isBoosted || ad.boostedUntil == null || ad.boostedUntil!.isBefore(DateTime.now())) ...[
                          _ActionButton(
                            label: 'ترقية',
                            icon: Icons.rocket_launch_rounded,
                            color: const Color(0xFFF59E0B),
                            onTap: handleBoost,
                          ),
                        ] else ...[
                          // Boosted indicator with remaining time
                          Column(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
                              Text(
                                'مميز',
                                style: TextStyle(fontSize: 10, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                              ),
                              Text(
                                _formatHoursLeft(ad.boostedUntil!),
                                style: TextStyle(fontSize: 8, color: AppTheme.neutralGray500),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Refresh button — only if 24h cooldown has passed
                        if (ad.canRefresh == true)
                          _ActionButton(
                            label: 'تحديث',
                            icon: Icons.refresh_rounded,
                            color: const Color(0xFF10B981),
                            onTap: handleRefresh,
                          )
                        else if (ad.nextRefreshAt != null)
                          Column(
                            children: [
                              Icon(Icons.refresh_rounded, size: 20, color: AppTheme.neutralGray400),
                              Text(
                                _formatHoursLeft(ad.nextRefreshAt!),
                                style: const TextStyle(fontSize: 8, color: AppTheme.neutralGray400),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        _ActionButton(label: 'مُباع', icon: Icons.sell_outlined, color: Colors.blue, onTap: handleMarkSold),
                        const SizedBox(height: 6),
                      ],
                      if (ad.status == 'active' || ad.status == 'pending_review') ...[
                        _ActionButton(
                          label: 'تعديل',
                          icon: Icons.edit_outlined,
                          color: AppTheme.primaryGreen,
                          // ✅ Wired: navigate to PostAdScreen in edit mode
                          onTap: () => context.push('/post-ad', extra: ad.id),
                        ),
                        const SizedBox(height: 6),
                      ],
                      _ActionButton(label: 'حذف', icon: Icons.delete_outline, color: Colors.red, onTap: handleDelete),
                    ],
                  ),
                ],
              ),

              // ── Expiry countdown (active ads ≤ 5 days) ─────────────────
              if (isExpiringSoon) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text(
                        daysRemaining == 0
                            ? 'ينتهي اليوم!'
                            : 'ينتهي خلال $daysRemaining ${daysRemaining == 1 ? "يوم" : "أيام"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ],
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

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _formatHoursLeft(DateTime until) {
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return '';
    if (diff.inHours > 24) return 'باقي ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'باقي ${diff.inHours} س';
    return 'باقي ${diff.inMinutes} د';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
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
              isAll ? 'لا توجد إعلانات بعد' : 'لا توجد إعلانات بحالة "$tabLabel"',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (isAll) ...[
              const SizedBox(height: 8),
              Text('انشر إعلانك الأول الآن!', style: TextStyle(color: AppTheme.neutralGray500)),
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
            Container(width: 80, height: 70, color: AppTheme.neutralGray100, margin: const EdgeInsets.only(right: 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, width: 60, color: AppTheme.neutralGray100),
                  const SizedBox(height: 8),
                  Container(height: 14, color: AppTheme.neutralGray100),
                  const SizedBox(height: 6),
                  Container(height: 14, width: 80, color: AppTheme.neutralGray100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
