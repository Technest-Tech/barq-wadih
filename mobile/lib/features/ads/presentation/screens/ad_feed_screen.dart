// lib/features/ads/presentation/screens/ad_feed_screen.dart
//
// Premium ad feed — Haraj-inspired:
// - Navy/Gold colored header with clean search bar.
// - Modern slide-out drawer.
// - Category tabs + subcategories + filter bar.
// - Theme-aware (dark mode safe).

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../categories/data/category_api.dart';
import '../../../categories/domain/category_model.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../../regions/domain/region_model.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/data/notification_providers.dart';
import '../../../settings/providers/locale_provider.dart';
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
  int? _selectedSubcategoryId;
  List<CityModel>? _selectedCities;
  List<CategoryModel> _subcategories = [];
  bool _isGridView = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  void _applyCategory(int? categoryId, List<CategoryModel> children) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null;
      _subcategories = children;
    });
    if (categoryId == null) {
      _filter = _filter.copyWith(
          clearCategory: true, clearCategoryIds: true, page: 1);
    } else if (children.isNotEmpty) {
      // Parent has subcategories — send all child IDs so the feed shows every
      // ad under this category regardless of which subcategory it belongs to.
      final childIds = children.map((c) => c.id).toList();
      _filter = _filter.copyWith(
          clearCategory: true, categoryIds: childIds, page: 1);
    } else {
      // Leaf category with no children — send its own ID directly.
      _filter = _filter.copyWith(
          categoryId: categoryId, clearCategoryIds: true, page: 1);
    }
    ref.read(adsFeedProvider.notifier).applyFilter(_filter);
  }

  void _applySubcategory(int? subcategoryId) {
    HapticFeedback.selectionClick();
    setState(() => _selectedSubcategoryId = subcategoryId);
    if (subcategoryId == null) {
      // "الكل" chip — show all ads under the parent by sending all child IDs.
      final childIds = _subcategories.map((c) => c.id).toList();
      _filter = _filter.copyWith(
          clearCategory: true, categoryIds: childIds, page: 1);
    } else {
      // Specific subcategory selected — send only its ID.
      _filter = _filter.copyWith(
          categoryId: subcategoryId, clearCategoryIds: true, page: 1);
    }
    ref.read(adsFeedProvider.notifier).applyFilter(_filter);
  }

  void _applySearch(String q) {
    _filter = _filter.copyWith(q: q, page: 1);
    ref.read(adsFeedProvider.notifier).applyFilter(_filter);
  }

  void _onSearchChanged(String q) {
    setState(() {});
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      _applySearch('');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _applySearch(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Consume any pending category navigation from the categories screen
    ref.listen(categoryNavProvider, (_, CategoryNav? nav) {
      if (nav == null) return;
      final cats = ref.read(categoriesProvider).asData?.value ?? [];
      CategoryModel? parentCat;
      try {
        parentCat = cats.firstWhere((c) => c.id == nav.categoryId);
      } catch (_) {}

      if (nav.subcategoryId != null) {
        setState(() {
          _selectedCategoryId    = nav.categoryId;
          _selectedSubcategoryId = nav.subcategoryId;
          _subcategories         = parentCat?.children ?? [];
        });
        _filter = _filter.copyWith(
            categoryId: nav.subcategoryId, clearCategoryIds: true, page: 1);
      } else if (parentCat != null && parentCat.children.isNotEmpty) {
        final childIds = parentCat.children.map((c) => c.id).toList();
        setState(() {
          _selectedCategoryId    = nav.categoryId;
          _selectedSubcategoryId = null;
          _subcategories         = parentCat!.children;
        });
        _filter = _filter.copyWith(
            clearCategory: true, categoryIds: childIds, page: 1);
      } else {
        setState(() {
          _selectedCategoryId    = nav.categoryId;
          _selectedSubcategoryId = null;
          _subcategories         = [];
        });
        _filter = _filter.copyWith(
            categoryId: nav.categoryId, clearCategoryIds: true, page: 1);
      }
      ref.read(adsFeedProvider.notifier).applyFilter(_filter);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(categoryNavProvider.notifier).clear();
      });
    });

    final feedState = ref.watch(adsFeedProvider);
    final categories = ref.watch(categoriesProvider);


    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.neutralGray50,
      resizeToAvoidBottomInset: false,
      // ── App Bar ────────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          elevation: 0,
          leadingWidth: 48,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => _openSidebarOverlay(),
          ),
          actions: [
            _NotifBell(notifAsync: ref.watch(unreadNotificationCountProvider)),
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
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded,
                    color: AppTheme.neutralGray400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.neutralGray900),
                    decoration: const InputDecoration(
                      hintText: 'ابحث في برق واضح...',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(
                          color: AppTheme.neutralGray400, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
                      filled: false,
                    ),
                    onSubmitted: _applySearch,
                    onChanged: _onSearchChanged,
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
                      child: Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.neutralGray400),
                    ),
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),

      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, _) => [
          // الحالات (Stories) مؤجلة لما بعد الإطلاق
          // SliverToBoxAdapter(
          //   child: Container(
          //     color: Colors.white,
          //     child: const StoriesRow(),
          //   ),
          // ),

          // ── Main Categories (pinned) ────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedCategoriesHeader(
              child: Container(
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
                          label: cat.nameAr,
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
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
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
                            child: _SubCategoryChip(
                              label: 'الكل',
                              isPrimary: _selectedSubcategoryId == null,
                              onTap: () => _applySubcategory(null),
                            ),
                          );
                        }
                        final sub = _subcategories[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _SubCategoryChip(
                            label: sub.nameAr,
                            isPrimary: _selectedSubcategoryId == sub.id,
                            onTap: () => _applySubcategory(sub.id),
                          ),
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
                return CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        onPostAd: ref.read(authProvider) is AuthAuthenticated
                            ? () => context.push('/post-ad')
                            : null,
                      ),
                    ),
                  ],
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
    final currentAuthState = ref.read(authProvider);
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return _SidebarOverlayRoute(
            appBarHeight: MediaQuery.of(ctx).padding.top + 60.0,
            authState: currentAuthState,
            onAuthNavigate: () => context.push('/login'),
            onNavigateTo: (route) => context.push(route),
            onShare: _shareApp,
            onLogout: () => ref.read(authProvider.notifier).logout(),
          );
        },
      ),
    );
  }

  Future<void> _shareApp() async {
    final text = Uri.encodeComponent(
        'حمّل تطبيق برق واضح للإعلانات المبوبة في المملكة العربية السعودية!');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}


  // ── Haraj-Style Drawer ──────────────────────────────────────────────────
class _SidebarOverlayRoute extends ConsumerStatefulWidget {
  final double appBarHeight;
  final AuthState authState;
  final VoidCallback onAuthNavigate;
  final void Function(String route) onNavigateTo;
  final VoidCallback onShare;
  final VoidCallback onLogout;

  const _SidebarOverlayRoute({
    required this.appBarHeight,
    required this.authState,
    required this.onAuthNavigate,
    required this.onNavigateTo,
    required this.onShare,
    required this.onLogout,
  });

  @override
  ConsumerState<_SidebarOverlayRoute> createState() =>
      _SidebarOverlayRouteState();
}

class _SidebarOverlayRouteState extends ConsumerState<_SidebarOverlayRoute>
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

  void _closeAndNavigate(String route) {
    _ctrl.reverse().then((_) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onNavigateTo(route);
    });
  }

  void _closeAndShare() {
    _ctrl.reverse().then((_) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onShare();
    });
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _LanguageSheet(
        currentLocale: ref.read(localeProvider),
        onSelect: (locale) {
          ref.read(localeProvider.notifier).setLocale(locale);
          Navigator.pop(sheetCtx);
        },
      ),
    );
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
                      right: _slideAnim.value,
                      width: 280,
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
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';
    final isAuthenticated = widget.authState is AuthAuthenticated;
    final AuthUser? user =
        isAuthenticated ? (widget.authState as AuthAuthenticated).user : null;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),

        // ── Auth Section (conditional) ─────────────────────────────────
        if (isAuthenticated && user != null) ...[
          _buildUserHeader(user),
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                _HarajDrawerItem(
                  icon: Icons.favorite_border_rounded,
                  title: 'المفضلة',
                  onTap: () => _closeAndNavigate('/favorites'),
                ),
                const _Divider(),
                // TODO: re-enable when my-ads screen is ready
                // _HarajDrawerItem(
                //   icon: Icons.list_alt_rounded,
                //   title: 'إعلاناتي',
                //   onTap: () => _closeAndNavigate('/my-ads'),
                // ),
                // const _Divider(),
                _HarajDrawerItem(
                  icon: Icons.notifications_outlined,
                  title: 'الإشعارات',
                  badge: user.unreadNotificationsCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${user.unreadNotificationsCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        )
                      : null,
                  onTap: () => _closeAndNavigate('/notifications'),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              minVerticalPadding: 0,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
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
                _ctrl.reverse().then((_) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onAuthNavigate();
                });
              },
            ),
          ),
        ],

        // ── Shared Items ───────────────────────────────────────────────
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              _HarajDrawerItem(
                icon: Icons.payments_outlined,
                title: 'سداد الرسوم والاشتراكات',
                onTap: () => _closeAndNavigate('/payments'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.star_outline_rounded,
                title: 'مميزات وخدمات',
                subtitle: 'الخصم،التقييم،العروض المميزة..',
                onTap: () => _closeAndNavigate('/features-services'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.phone_in_talk_outlined,
                title: 'اتصل بنا',
                onTap: () => _closeAndNavigate('/contact-us'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.share_outlined,
                title: 'شارك تطبيق برق واضح',
                onTap: _closeAndShare,
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.description_outlined,
                title: 'سياسة موقع برق واضح',
                onTap: () => _closeAndNavigate('/privacy-policy'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.gavel_rounded,
                title: 'شروط الاستخدام',
                onTap: () => _closeAndNavigate('/terms-of-service'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.security_outlined,
                title: 'مركز الأمان',
                onTap: () => _closeAndNavigate('/safety-center'),
              ),
              // خدمة الشراء الموثوق: مؤجلة لما بعد الإطلاق
              // _HarajDrawerItem(
              //   icon: Icons.shopping_cart_outlined,
              //   title: 'خدمة الشراء الموثوق',
              //   onTap: () => _closeAndNavigate('/trusted-purchase'),
              // ),
            ],
          ),
        ),

        // TODO: re-enable night mode toggle when dark theme is fully designed
        // Container(
        //   color: Colors.white,
        //   margin: const EdgeInsets.only(bottom: 6),
        //   child: ListTile(
        //     ...
        //   ),
        // ),

        // ── Logout (authenticated only) ────────────────────────────────
        if (isAuthenticated)
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              minVerticalPadding: 0,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.logout_rounded,
                  color: Colors.red, size: 22),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              onTap: _showLogoutDialog,
            ),
          ),

        // Footer: Language + version
        GestureDetector(
          onTap: _showLanguageSheet,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language_outlined,
                        color: Color(0xFF555555), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'العربية / English' : 'English / العربية',
                      style: const TextStyle(
                          color: Color(0xFF555555), fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_less_rounded,
                        color: Color(0xFF555555), size: 14),
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
        ),
      ],
    );
  }

  Widget _buildUserHeader(AuthUser user) {
    return GestureDetector(
      onTap: () => _closeAndNavigate('/profile'),
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              backgroundColor: const Color(0xFF1B3A6B),
              child: user.avatarUrl == null
                  ? Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((user.email ?? user.phone) != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? user.phone!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF777777)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                color: Color(0xFFAAAAAA), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'هل تريد تسجيل الخروج من حسابك؟',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
              Navigator.pop(context);
            },
            child: const Text('تسجيل الخروج',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Language Picker Sheet ─────────────────────────────────────────────────────

class _LanguageSheet extends StatelessWidget {
  final Locale currentLocale;
  final void Function(Locale) onSelect;

  const _LanguageSheet({required this.currentLocale, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('اختر اللغة / Choose Language',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _buildLocaleOption(
            context,
            label: 'العربية',
            sublabel: 'Arabic',
            locale: const Locale('ar', 'SA'),
          ),
          const SizedBox(height: 8),
          _buildLocaleOption(
            context,
            label: 'English',
            sublabel: 'الإنجليزية',
            locale: const Locale('en', 'US'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocaleOption(
    BuildContext context, {
    required String label,
    required String sublabel,
    required Locale locale,
  }) {
    final isSelected = currentLocale.languageCode == locale.languageCode;
    return InkWell(
      onTap: () => onSelect(locale),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: .07)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: .4)
                : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.neutralGray800)),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.neutralGray500)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Components ───────────────────────────────────────────────────────────────

class _HarajDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback onTap;

  const _HarajDrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
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
          color: Colors.black,
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
      trailing: badge != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                badge!,
                const SizedBox(width: 6),
                const Icon(Icons.chevron_left_rounded,
                    color: Color(0xFFB0BEC5), size: 18),
              ],
            )
          : const Icon(Icons.chevron_left_rounded,
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

class _PinnedCategoriesHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _PinnedCategoriesHeader({required this.child});

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedCategoriesHeader oldDelegate) {
    return oldDelegate.child != child;
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
  final VoidCallback? onTap;

  const _SubCategoryChip({required this.label, this.isPrimary = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isPrimary ? AppTheme.primaryBlue : AppTheme.neutralGray200,
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

// ── Notification bell icon for AppBar ─────────────────────────────────────────

class _NotifBell extends StatelessWidget {
  final AsyncValue<int> notifAsync;
  const _NotifBell({required this.notifAsync});

  @override
  Widget build(BuildContext context) {
    final count = notifAsync.when(
      data: (c) => c,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () => context.push('/notifications'),
          tooltip: 'الإشعارات',
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFD63031),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
