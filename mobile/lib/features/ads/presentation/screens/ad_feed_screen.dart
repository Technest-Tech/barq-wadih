// lib/features/ads/presentation/screens/ad_feed_screen.dart
//
// Premium ad feed — Haraj-inspired:
// - Navy/Gold colored header with clean search bar.
// - Modern slide-out drawer.
// - Category tabs + subcategories + filter bar.
// - Theme-aware (dark mode safe).

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../categories/data/category_api.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../../regions/domain/region_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/ad_api.dart';
import '../widgets/ad_card.dart';
import '../../../stories/presentation/stories_row.dart';

class AdFeedScreen extends ConsumerStatefulWidget {
  const AdFeedScreen({super.key});

  @override
  ConsumerState<AdFeedScreen> createState() => _AdFeedScreenState();
}

class _AdFeedScreenState extends ConsumerState<AdFeedScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AdsFilter _filter = const AdsFilter();
  int? _selectedCategoryId;
  List<CityModel>? _selectedCities;
  List<dynamic> _subcategories = [];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(adsFeedProvider.notifier).loadMore();
    }
  }

  void _applyCategory(int? categoryId, List<dynamic> children) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryId = categoryId;
      _subcategories = children;
    });
    final updated = categoryId == null
        ? _filter.copyWith(clearCategory: true, page: 1)
        : _filter.copyWith(categoryId: categoryId, page: 1);
    _filter = updated;
    ref.read(adsFeedProvider.notifier).applyFilter(_filter);
  }

  void _applySearch(String q) {
    _filter = _filter.copyWith(q: q, page: 1);
    ref.read(adsFeedProvider.notifier).applyFilter(_filter);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(adsFeedProvider);
    final categories = ref.watch(categoriesProvider);


    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.neutralGray50,
      // ── App Bar ────────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          elevation: 0,
          leadingWidth: 48,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => _openSidebarOverlay(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
              onPressed: () => context.push('/categories'),
            ),
          ],
          title: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 14, color: AppTheme.neutralGray900),
                    decoration: const InputDecoration(
                      hintText: 'ابحث في برق واضح',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      filled: false,
                    ),
                    onSubmitted: _applySearch,
                    onChanged: (v) {
                      setState(() {});
                      if (v.isEmpty) _applySearch('');
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _applySearch('');
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.close_rounded, size: 18, color: AppTheme.neutralGray500),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.search_rounded, color: AppTheme.neutralGray500, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),

      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Stories Row ────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  child: const StoriesRow(),
                ),

                // ── Main Categories ──────────────────────────────────────────
                Container(
                  color: Colors.white,
                  child: categories.when(
                    data: (cats) => Container(
                      height: 46,
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: AppTheme.neutralGray200,
                          width: 1,
                        )),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: cats.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return _MainCategoryTab(
                              label: 'الكل',
                              selected: _selectedCategoryId == null,
                              onTap: () => _applyCategory(null, []),
                            );
                          }
                          final cat = cats[i - 1];
                          return _MainCategoryTab(
                            label: '${cat.icon ?? ''} ${cat.nameAr}'.trim(),
                            selected: _selectedCategoryId == cat.id,
                            onTap: () => _applyCategory(cat.id, cat.children),
                          );
                        },
                      ),
                    ),
                    loading: () => const SizedBox(height: 46),
                    error: (_, __) => const SizedBox(height: 46),
                  ),
                ),

                // ── Subcategories (real data from category children) ──────────
                if (_selectedCategoryId != null && _subcategories.isNotEmpty)
                  Container(
                    height: 38,
                    color: Colors.white,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                      itemCount: _subcategories.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _SubCategoryChip(label: 'الكل', isPrimary: true),
                          );
                        }
                        final sub = _subcategories[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _SubCategoryChip(label: sub.nameAr),
                        );
                      },
                    ),
                  ),

                // ── Filter Bar ────────────────────────────────────────────
                Container(
                  height: 46,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // Region/City Dropdown
                      GestureDetector(
                        onTap: () async {
                          final result = await showRegionCityPicker(
                            context,
                            ref,
                            isMultiSelect: true,
                            initialSelection: _selectedCities,
                          );
                          if (result != null) {
                            setState(() {
                              _selectedCities = result.isEmpty ? null : result;
                            });
                            _filter = _filter.copyWith(
                              clearCityIds: result.isEmpty,
                              cityIds: result.isEmpty ? null : result.map((c) => c.id).toList(),
                              page: 1,
                            );
                            ref.read(adsFeedProvider.notifier).applyFilter(_filter);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.neutralGray200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.primaryBlue),
                              const SizedBox(width: 3),
                              Text(
                                _selectedCities != null && _selectedCities!.isNotEmpty
                                    ? _selectedCities!.length == 1
                                        ? _selectedCities!.first.nameAr
                                        : '${_selectedCities!.length} مدن'
                                    : 'كل المدن',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.neutralGray800,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppTheme.neutralGray500),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push('/search'),
                        child: const _ThemedFilterChip(label: 'تصفية', icon: Icons.filter_alt_outlined),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push('/search'),
                        child: const _ThemedFilterChip(label: 'بحث متقدم', icon: Icons.manage_search_rounded),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isGridView = !_isGridView);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          color: Colors.transparent,
                          child: Icon(
                            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                            color: AppTheme.neutralGray500,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 6,
                  color: AppTheme.neutralGray100,
                ),
              ],
            ),
          ),
        ],

        // ── Ad List ──────────────────────────────────────────────────────────
        body: RefreshIndicator(
          onRefresh: () => ref.read(adsFeedProvider.notifier).refresh(),
          color: AppTheme.primaryBlue,        // navy spinner on white bg
          backgroundColor: Colors.white,       // always white pull-down bg
          child: feedState.when(
            data: (feed) {
              if (feed.ads.isEmpty) {
                return _EmptyState(
                  onPostAd: ref.read(authProvider) is AuthAuthenticated
                      ? () => context.push('/post-ad')
                      : null,
                );
              }
              if (_isGridView) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: feed.hasMore ? feed.ads.length + 1 : feed.ads.length,
                  itemBuilder: (context, i) {
                    if (i >= feed.ads.length) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    }
                    final ad = feed.ads[i];
                    return _AnimatedAdCard(
                      index: i,
                      child: AdCard(ad: ad, isGrid: true, onTap: () => context.push('/ads/${ad.id}')),
                    );
                  },
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: feed.hasMore ? feed.ads.length + 1 : feed.ads.length,
                itemBuilder: (context, i) {
                  if (i >= feed.ads.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,   // always navy
                          backgroundColor: Colors.transparent,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  }
                  final ad = feed.ads[i];
                  return _AnimatedAdCard(
                    index: i,
                    child: AdCard(ad: ad, isGrid: false, onTap: () => context.push('/ads/${ad.id}')),
                  );
                },
              );
            },
            loading: () => ListView.separated(
              padding: const EdgeInsets.only(bottom: 100),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (_, __) => const AdListTileShimmer(),
            ),
            error: (err, _) => Center(
              child: _ErrorState(onRetry: () => ref.read(adsFeedProvider.notifier).refresh()),
            ),
          ),
        ),
      ),
    );
  }

  void _openSidebarOverlay() {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _SidebarOverlayRoute(
            appBarHeight: MediaQuery.of(context).padding.top + 60.0,
            authProviderRef: ref.read(authProvider),
            onAuthNavigate: () => context.push('/login'),
          );
        },
      ),
    );
  }
}


  // ── Haraj-Style Drawer ──────────────────────────────────────────────────
class _SidebarOverlayRoute extends StatefulWidget {
  final double appBarHeight;
  final AuthState authProviderRef;
  final VoidCallback onAuthNavigate;

  const _SidebarOverlayRoute({
    required this.appBarHeight,
    required this.authProviderRef,
    required this.onAuthNavigate,
  });

  @override
  State<_SidebarOverlayRoute> createState() => _SidebarOverlayRouteState();
}

class _SidebarOverlayRouteState extends State<_SidebarOverlayRoute>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<double>(begin: -280, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  void _close() {
    _ctrl.reverse().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GestureDetector(
            onTap: _close,
            child: Container(
              height: widget.appBarHeight,
              color: Colors.transparent,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _close,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                          child: Container(
                            color: Colors.black.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, child) {
                    return Positioned(
                      top: 0,
                      bottom: 0,
                      right: _slideAnim.value, // RTL aligns Right
                      width: 280, // slightly narrower, compact
                      child: child!,
                    );
                  },
                  child: Container(
                    color: const Color(0xFFF7F9FA),
                    child: SafeArea(
                      top: false,
                      child: _buildDrawerContent(),
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

  Widget _buildDrawerContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),

        // Top Auth Item
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            minVerticalPadding: 0,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.login_rounded,
                color: Color(0xFF0DA37F), size: 22),
            title: const Text(
              'تسجيل دخول / حساب جديد',
              style: TextStyle(
                color: Color(0xFF0DA37F),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              _close();
              if (widget.authProviderRef is AuthUnauthenticated) {
                widget.onAuthNavigate();
              }
            },
          ),
        ),

        // Middle Group 1
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              _HarajDrawerItem(
                icon: Icons.payments_outlined,
                title: 'سداد الرسوم والاشتراكات',
                onTap: () {},
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.star_outline_rounded,
                title: 'مميزات وخدمات',
                subtitle: 'الخصم،التقييم،العروض المميزة..',
                onTap: () {},
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.phone_in_talk_outlined,
                title: 'اتصل بنا',
                onTap: () {},
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.share_outlined,
                title: 'شارك تطبيق برق واضح',
                onTap: () {},
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.description_outlined,
                title: 'سياسة موقع برق واضح',
                onTap: () {},
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.security_outlined,
                title: 'مركز الأمان',
                onTap: () {},
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.shopping_cart_outlined,
                title: 'خدمة الشراء الموثوق',
                onTap: () {},
              ),
            ],
          ),
        ),

        // Middle Group 2: Night Mode
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            minVerticalPadding: 0,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.dark_mode_outlined,
                color: Color(0xFF465A71), size: 22),
            title: const Text(
              'الوضع الليلي',
              style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            trailing: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: false,
                onChanged: (val) {},
                activeColor: const Color(0xFF465A71),
              ),
            ),
            onTap: () {},
          ),
        ),

        // Footer Group
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.language_outlined,
                      color: Color(0xFF555555), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'اللغة / Language / زبان',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'برق واضح v1.0.0',
                style: TextStyle(color: Color(0xFF999999), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Components ───────────────────────────────────────────────────────────────

class _HarajDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _HarajDrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minVerticalPadding: 0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon, color: const Color(0xFF465A71), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_left_rounded,
          color: Color(0xFFB0BEC5), size: 18),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2));
  }
}

class _MainCategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MainCategoryTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppTheme.primaryBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppTheme.primaryBlue
                  : AppTheme.neutralGray600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubCategoryChip extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _SubCategoryChip({required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppTheme.primaryBlue
            : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isPrimary
              ? AppTheme.primaryBlue
              : AppTheme.neutralGray200,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
          color: isPrimary ? Colors.white : AppTheme.neutralGray700,
        ),
      ),
    );
  }
}

class _ThemedFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _ThemedFilterChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppTheme.neutralGray600),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.neutralGray800,
          )),
        ],
      ),
    );
  }
}

// ── Shared animations & states ────────────────────────────────────────────────

class _AnimatedAdCard extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedAdCard({required this.child, required this.index});

  @override
  State<_AnimatedAdCard> createState() => _AnimatedAdCardState();
}

class _AnimatedAdCardState extends State<_AnimatedAdCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    final delay = Duration(milliseconds: (widget.index % 6) * 50);
    Future.delayed(delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _ctrl, child: widget.child);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onPostAd;
  const _EmptyState({this.onPostAd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined, size: 48, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد إعلانات',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: AppTheme.neutralGray800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'كن أول من ينشر إعلاناً في هذا القسم',
              style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500),
              textAlign: TextAlign.center,
            ),
            if (onPostAd != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onPostAd,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('أضف إعلانك'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppTheme.neutralGray100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, size: 36, color: AppTheme.neutralGray500),
        ),
        const SizedBox(height: 16),
        const Text('تعذّر تحميل الإعلانات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.neutralGray900)),
        const SizedBox(height: 6),
        const Text('تحقّق من الاتصال وأعد المحاولة',
            style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
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
    );
  }
}
