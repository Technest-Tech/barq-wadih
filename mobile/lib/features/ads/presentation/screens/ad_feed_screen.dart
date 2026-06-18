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
  Timer? _suggestDebounce;
  final FocusNode _searchFocus = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  bool get _hasActiveFilters =>
      _filter.priceMin != null ||
      _filter.priceMax != null ||
      (_filter.q?.isNotEmpty ?? false) ||
      _filter.sort != 'newest';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _suggestDebounce?.cancel();
    _searchFocus.dispose();
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
        clearCategory: true,
        clearCategoryIds: true,
        page: 1,
      );
    } else if (children.isNotEmpty) {
      // Parent has subcategories — send all child IDs so the feed shows every
      // ad under this category regardless of which subcategory it belongs to.
      final childIds = children.map((c) => c.id).toList();
      _filter = _filter.copyWith(
        clearCategory: true,
        categoryIds: childIds,
        page: 1,
      );
    } else {
      // Leaf category with no children — send its own ID directly.
      _filter = _filter.copyWith(
        categoryId: categoryId,
        clearCategoryIds: true,
        page: 1,
      );
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
        clearCategory: true,
        categoryIds: childIds,
        page: 1,
      );
    } else {
      // Specific subcategory selected — send only its ID.
      _filter = _filter.copyWith(
        categoryId: subcategoryId,
        clearCategoryIds: true,
        page: 1,
      );
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
    _suggestDebounce?.cancel();
    if (q.isEmpty) {
      _applySearch('');
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    if (q.length >= 2) {
      _suggestDebounce = Timer(const Duration(milliseconds: 200), () async {
        try {
          final s = await ref
              .read(adRepositoryProvider)
              .getSearchSuggestions(q);
          if (mounted) {
            setState(() {
              _suggestions = s;
              _showSuggestions = s.isNotEmpty;
            });
          }
        } catch (_) {}
      });
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      _applySearch(q);
    });
  }

  void _onSuggestionSelected(String s) {
    _searchController.text = s;
    _applySearch(s);
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
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
          _selectedCategoryId = nav.categoryId;
          _selectedSubcategoryId = nav.subcategoryId;
          _subcategories = parentCat?.children ?? [];
        });
        _filter = _filter.copyWith(
          categoryId: nav.subcategoryId,
          clearCategoryIds: true,
          page: 1,
        );
      } else if (parentCat != null && parentCat.children.isNotEmpty) {
        final childIds = parentCat.children.map((c) => c.id).toList();
        setState(() {
          _selectedCategoryId = nav.categoryId;
          _selectedSubcategoryId = null;
          _subcategories = parentCat!.children;
        });
        _filter = _filter.copyWith(
          clearCategory: true,
          categoryIds: childIds,
          page: 1,
        );
      } else {
        setState(() {
          _selectedCategoryId = nav.categoryId;
          _selectedSubcategoryId = null;
          _subcategories = [];
        });
        _filter = _filter.copyWith(
          categoryId: nav.categoryId,
          clearCategoryIds: true,
          page: 1,
        );
      }
      ref.read(adsFeedProvider.notifier).applyFilter(_filter);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(categoryNavProvider.notifier).clear();
      });
    });

    final feedState = ref.watch(adsFeedProvider);
    final categories = ref.watch(categoriesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedCategoryId != null) {
          _applyCategory(null, []);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
              _NotifBell(
                notifAsync: ref.watch(authProvider) is AuthAuthenticated
                    ? ref.watch(unreadNotificationCountProvider)
                    : const AsyncValue<int>.data(0),
              ),
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
                  const Icon(
                    Icons.search_rounded,
                    color: AppTheme.neutralGray400,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutralGray900,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'ابحث في برق واضح...',
                        hintTextDirection: TextDirection.rtl,
                        hintStyle: TextStyle(
                          color: AppTheme.neutralGray400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        filled: false,
                      ),
                      focusNode: _searchFocus,
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
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.neutralGray400,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),

        body: Stack(
          children: [
            NestedScrollView(
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
                            border: Border(
                              bottom: BorderSide(
                                color: AppTheme.neutralGray200,
                                width: 1,
                              ),
                            ),
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
                                onTap: () =>
                                    _applyCategory(cat.id, cat.children),
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
                      if (_selectedCategoryId != null &&
                          _subcategories.isNotEmpty)
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
                                    _selectedCities = result.isEmpty
                                        ? null
                                        : result;
                                  });
                                  _filter = _filter.copyWith(
                                    clearCityIds: result.isEmpty,
                                    cityIds: result.isEmpty
                                        ? null
                                        : result.map((c) => c.id).toList(),
                                    page: 1,
                                  );
                                  ref
                                      .read(adsFeedProvider.notifier)
                                      .applyFilter(_filter);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.neutralGray200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _selectedCities != null &&
                                              _selectedCities!.isNotEmpty
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
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 14,
                                      color: AppTheme.neutralGray500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showFilterSheet,
                              child: _ThemedFilterChip(
                                label: 'تصفية',
                                icon: Icons.filter_alt_outlined,
                                isActive: _hasActiveFilters,
                              ),
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
                                  _isGridView
                                      ? Icons.view_list_rounded
                                      : Icons.grid_view_rounded,
                                  color: AppTheme.neutralGray500,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Container(height: 6, color: AppTheme.neutralGray100),
                    ],
                  ),
                ),
              ],

              // ── Ad List ──────────────────────────────────────────────────────────
              body: RefreshIndicator(
                onRefresh: () => ref.read(adsFeedProvider.notifier).refresh(),
                color: AppTheme.primaryBlue, // navy spinner on white bg
                backgroundColor: Colors.white, // always white pull-down bg
                child: feedState.when(
                  data: (feed) {
                    if (feed.ads.isEmpty) {
                      return CustomScrollView(
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              searchQuery: _filter.q,
                              categoryId: _selectedCategoryId,
                              onPostAd:
                                  ref.read(authProvider) is AuthAuthenticated
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.65,
                            ),
                        itemCount: feed.hasMore
                            ? feed.ads.length + 1
                            : feed.ads.length,
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
                            child: AdCard(
                              ad: ad,
                              isGrid: true,
                              onTap: () => context.push('/ads/${ad.id}'),
                            ),
                          );
                        },
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: feed.hasMore
                          ? feed.ads.length + 1
                          : feed.ads.length,
                      itemBuilder: (context, i) {
                        if (i >= feed.ads.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue, // always navy
                                backgroundColor: Colors.transparent,
                                strokeWidth: 2.5,
                              ),
                            ),
                          );
                        }
                        final ad = feed.ads[i];
                        return _AnimatedAdCard(
                          index: i,
                          child: AdCard(
                            ad: ad,
                            isGrid: false,
                            onTap: () => context.push('/ads/${ad.id}'),
                          ),
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
                    child: _ErrorState(
                      onRetry: () =>
                          ref.read(adsFeedProvider.notifier).refresh(),
                    ),
                  ),
                ),
              ),
            ),
            if (_showSuggestions && _suggestions.isNotEmpty)
              _SuggestionsPanel(
                suggestions: _suggestions,
                query: _searchController.text,
                onSelect: _onSuggestionSelected,
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        currentFilter: _filter,
        onApply: (newFilter) {
          setState(() => _filter = newFilter);
          ref.read(adsFeedProvider.notifier).applyFilter(newFilter);
        },
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
      'حمّل تطبيق برق واضح للإعلانات المبوبة في المملكة العربية السعودية!',
    );
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
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<double>(
      begin: -280,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
                            color: Colors.black.withValues(alpha: 0.4),
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
                    child: SafeArea(top: false, child: _buildDrawerContent()),
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
    final AuthUser? user = isAuthenticated
        ? (widget.authState as AuthAuthenticated).user
        : null;

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
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${user.unreadNotificationsCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(
                Icons.login_rounded,
                color: Color(0xFF0DA37F),
                size: 22,
              ),
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
                icon: Icons.shopping_bag_outlined,
                title: 'كيف تشتري؟',
                onTap: () => _closeAndNavigate('/how-to-buy'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.sell_outlined,
                title: 'كيف تبيع؟',
                onTap: () => _closeAndNavigate('/how-to-sell'),
              ),
              const _Divider(),
              _HarajDrawerItem(
                icon: Icons.payments_outlined,
                title: 'سداد العمولات',
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
                icon: Icons.info_outline_rounded,
                title: 'من نحن',
                onTap: () => _closeAndNavigate('/about'),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 22,
              ),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
                    const Icon(
                      Icons.language_outlined,
                      color: Color(0xFF555555),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'العربية / English' : 'English / العربية',
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less_rounded,
                      color: Color(0xFF555555),
                      size: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((user.email ?? user.phone) != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? user.phone!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFAAAAAA),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'تسجيل الخروج',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'هل تريد تسجيل الخروج من حسابك؟',
          textAlign: TextAlign.center,
        ),
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
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red),
            ),
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
          const Text(
            'اختر اللغة / Choose Language',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
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
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : AppTheme.neutralGray800,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutralGray500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
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
              style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
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
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFFB0BEC5),
                  size: 18,
                ),
              ],
            )
          : const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFB0BEC5),
              size: 18,
            ),
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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

  const _MainCategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
              color: selected ? AppTheme.primaryBlue : AppTheme.neutralGray600,
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

  const _SubCategoryChip({
    required this.label,
    this.isPrimary = false,
    this.onTap,
  });

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
  final bool isActive;

  const _ThemedFilterChip({
    required this.label,
    this.icon,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryBlue.withValues(alpha: .08)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.primaryBlue : AppTheme.neutralGray200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isActive ? AppTheme.primaryBlue : AppTheme.neutralGray600,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppTheme.primaryBlue : AppTheme.neutralGray800,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
            ),
          ],
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

class _AnimatedAdCardState extends State<_AnimatedAdCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final delay = Duration(milliseconds: (widget.index % 6) * 50);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _ctrl, child: widget.child);
  }
}

class _EmptyState extends ConsumerWidget {
  final VoidCallback? onPostAd;
  final String? searchQuery;
  final int? categoryId;

  const _EmptyState({this.onPostAd, this.searchQuery, this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearchEmpty = searchQuery != null && searchQuery!.isNotEmpty;

    if (isSearchEmpty) {
      final popularAsync = ref.watch(
        popularAdsProvider((limit: 3, categoryId: categoryId)),
      );
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppTheme.neutralGray400,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد نتائج لـ "$searchQuery"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'جرّب بحثاً مختلفاً أو تصفّح الفئات',
                style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500),
              ),
              const SizedBox(height: 28),
              popularAsync.when(
                data: (ads) {
                  if (ads.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'ربما يعجبك',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.neutralGray800,
                          ),
                        ),
                      ),
                      ...ads.map(
                        (ad) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: AdCard(
                            ad: ad,
                            onTap: () => context.push('/ads/${ad.id}'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد إعلانات',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.neutralGray100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
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
        const SizedBox(height: 6),
        const Text(
          'تحقّق من الاتصال وأعد المحاولة',
          style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('إعادة المحاولة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final AdsFilter currentFilter;
  final void Function(AdsFilter) onApply;

  const _FilterSheet({required this.currentFilter, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sort;
  bool _negotiable = false;
  final _priceMinCtrl = TextEditingController();
  final _priceMaxCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();
  bool _minFocused = false;
  bool _maxFocused = false;

  static const _pricePresets = [
    (label: 'أقل من 500', min: null, max: 500.0),
    (label: '500 – 2,000', min: 500.0, max: 2000.0),
    (label: '2,000 – 10,000', min: 2000.0, max: 10000.0),
    (label: 'أكثر من 10,000', min: 10000.0, max: null),
  ];

  static const _sortOptions = [
    (value: 'newest', label: 'الأحدث', icon: Icons.bolt_rounded),
    (value: 'oldest', label: 'الأقدم', icon: Icons.history_rounded),
    (value: 'price_asc', label: 'الأرخص', icon: Icons.trending_down_rounded),
    (value: 'price_desc', label: 'الأغلى', icon: Icons.trending_up_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _sort = widget.currentFilter.sort;
    _negotiable = widget.currentFilter.negotiable ?? false;
    if (widget.currentFilter.priceMin != null) {
      _priceMinCtrl.text = widget.currentFilter.priceMin!.toStringAsFixed(0);
    }
    if (widget.currentFilter.priceMax != null) {
      _priceMaxCtrl.text = widget.currentFilter.priceMax!.toStringAsFixed(0);
    }
    if (widget.currentFilter.q?.isNotEmpty ?? false) {
      _keywordCtrl.text = widget.currentFilter.q!;
    }
    _minFocus.addListener(
      () => setState(() => _minFocused = _minFocus.hasFocus),
    );
    _maxFocus.addListener(
      () => setState(() => _maxFocused = _maxFocus.hasFocus),
    );
    // Typing in a price field clears the "على السوم" toggle
    _priceMinCtrl.addListener(_onPriceTyped);
    _priceMaxCtrl.addListener(_onPriceTyped);
  }

  void _onPriceTyped() {
    if (_negotiable &&
        (_priceMinCtrl.text.isNotEmpty || _priceMaxCtrl.text.isNotEmpty)) {
      setState(() => _negotiable = false);
    }
  }

  @override
  void dispose() {
    _priceMinCtrl.dispose();
    _priceMaxCtrl.dispose();
    _keywordCtrl.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  int get _activeCount {
    int n = 0;
    if (_sort != 'newest') n++;
    if (_negotiable) n++;
    if (_priceMinCtrl.text.isNotEmpty) n++;
    if (_priceMaxCtrl.text.isNotEmpty) n++;
    if (_keywordCtrl.text.isNotEmpty) n++;
    return n;
  }

  String get _rangeSummary {
    if (_negotiable) return 'على السوم';
    final minTxt = _priceMinCtrl.text.trim();
    final maxTxt = _priceMaxCtrl.text.trim();
    if (minTxt.isEmpty && maxTxt.isEmpty) return 'غير محدد';
    if (minTxt.isEmpty) return 'حتى $maxTxt ر.س';
    if (maxTxt.isEmpty) return 'من $minTxt ر.س';
    return '$minTxt – $maxTxt ر.س';
  }

  bool _isPresetSelected(double? min, double? max) {
    if (_negotiable) return false;
    final curMin = double.tryParse(_priceMinCtrl.text.trim());
    final curMax = double.tryParse(_priceMaxCtrl.text.trim());
    return curMin == min && curMax == max;
  }

  void _applyPreset(double? min, double? max) {
    setState(() {
      _negotiable = false;
      _priceMinCtrl.text = min != null ? min.toStringAsFixed(0) : '';
      _priceMaxCtrl.text = max != null ? max.toStringAsFixed(0) : '';
    });
  }

  void _toggleNegotiable() {
    setState(() {
      _negotiable = !_negotiable;
      if (_negotiable) {
        _priceMinCtrl.clear();
        _priceMaxCtrl.clear();
      }
    });
  }

  void _reset() {
    setState(() {
      _sort = 'newest';
      _negotiable = false;
      _priceMinCtrl.clear();
      _priceMaxCtrl.clear();
      _keywordCtrl.clear();
    });
  }

  void _apply() {
    final priceMin = _negotiable
        ? null
        : double.tryParse(_priceMinCtrl.text.trim());
    final priceMax = _negotiable
        ? null
        : double.tryParse(_priceMaxCtrl.text.trim());
    final keyword = _keywordCtrl.text.trim();
    widget.onApply(
      AdsFilter(
        categoryId: widget.currentFilter.categoryId,
        categoryIds: widget.currentFilter.categoryIds,
        cityId: widget.currentFilter.cityId,
        cityIds: widget.currentFilter.cityIds,
        regionId: widget.currentFilter.regionId,
        priceMin: priceMin,
        priceMax: priceMax,
        q: keyword.isEmpty ? null : keyword,
        sort: _sort,
        negotiable: _negotiable ? true : null,
        page: 1,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeCount;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 14, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'تصفية الإعلانات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.neutralGray900,
                          ),
                        ),
                        if (active > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$active',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    GestureDetector(
                      onTap: _reset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.neutralGray100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.neutralGray200),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 13,
                              color: AppTheme.neutralGray600,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'مسح الكل',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.neutralGray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.neutralGray200),

              // ── Scrollable body ───────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Sort ───────────────────────────────────────
                      _sectionLabel('الترتيب', Icons.swap_vert_rounded),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3.2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _sortOptions.map((opt) {
                          final sel = _sort == opt.value;
                          return GestureDetector(
                            onTap: () => setState(() => _sort = opt.value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                gradient: sel
                                    ? const LinearGradient(
                                        colors: [
                                          AppTheme.primaryBlueLight,
                                          AppTheme.primaryBlue,
                                        ],
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomLeft,
                                      )
                                    : null,
                                color: sel ? null : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: sel
                                      ? Colors.transparent
                                      : AppTheme.neutralGray200,
                                ),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: .30),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: .04,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    opt.icon,
                                    size: 16,
                                    color: sel
                                        ? Colors.white
                                        : AppTheme.neutralGray400,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.neutralGray700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 28),

                      // ── Price range ─────────────────────────────────
                      _sectionLabel('نطاق السعر', Icons.payments_outlined),
                      const SizedBox(height: 12),

                      // Unified price card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.neutralGray200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Live summary header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: .05,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(17),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.price_change_outlined,
                                        size: 15,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'النطاق المحدد',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: _priceMinCtrl,
                                    builder: (_, __, ___) =>
                                        ValueListenableBuilder(
                                          valueListenable: _priceMaxCtrl,
                                          builder: (_, __, ___) => Text(
                                            _rangeSummary,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            // Two inputs — dimmed/disabled when على السوم active
                            AnimatedOpacity(
                              opacity: _negotiable ? 0.35 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: IgnorePointer(
                                ignoring: _negotiable,
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _priceInput(
                                          controller: _priceMinCtrl,
                                          focusNode: _minFocus,
                                          isFocused: _minFocused,
                                          label: 'الحد الأدنى',
                                          hint: '0',
                                          isRight: true,
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 1,
                                        color: AppTheme.neutralGray100,
                                      ),
                                      Expanded(
                                        child: _priceInput(
                                          controller: _priceMaxCtrl,
                                          focusNode: _maxFocus,
                                          isFocused: _maxFocused,
                                          label: 'الحد الأعلى',
                                          hint: 'بلا حد',
                                          isRight: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Preset chips + على السوم
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          children: [
                            // على السوم — special negotiable chip
                            GestureDetector(
                              onTap: _toggleNegotiable,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _negotiable
                                      ? AppTheme.accentGold
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _negotiable
                                        ? AppTheme.accentGold
                                        : AppTheme.neutralGray200,
                                  ),
                                  boxShadow: _negotiable
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.accentGold
                                                .withValues(alpha: .30),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: .04,
                                            ),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.handshake_outlined,
                                      size: 13,
                                      color: _negotiable
                                          ? Colors.white
                                          : AppTheme.neutralGray500,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'على السوم',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _negotiable
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _negotiable
                                            ? Colors.white
                                            : AppTheme.neutralGray700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Numeric range presets
                            ..._pricePresets.map((p) {
                              final sel = _isPresetSelected(p.min, p.max);
                              return GestureDetector(
                                onTap: () => _applyPreset(p.min, p.max),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppTheme.primaryBlue
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel
                                          ? AppTheme.primaryBlue
                                          : AppTheme.neutralGray200,
                                    ),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.primaryBlue
                                                  .withValues(alpha: .25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: .04,
                                              ),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Text(
                                    p.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.neutralGray700,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Keyword ────────────────────────────────────
                      _sectionLabel('الكلمة المفتاحية', Icons.search_rounded),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.neutralGray200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: AppTheme.neutralGray400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _keywordCtrl,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.neutralGray900,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'مثال: كامري 2022، آيفون 15، شقة...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.neutralGray400,
                                  ),
                                  hintTextDirection: TextDirection.rtl,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  suffixIcon: ValueListenableBuilder(
                                    valueListenable: _keywordCtrl,
                                    builder: (_, v, __) => v.text.isEmpty
                                        ? const SizedBox.shrink()
                                        : GestureDetector(
                                            onTap: () => setState(
                                              () => _keywordCtrl.clear(),
                                            ),
                                            child: const Icon(
                                              Icons.clear_rounded,
                                              size: 16,
                                              color: AppTheme.neutralGray400,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Apply button ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryBlueLight,
                          AppTheme.primaryBlue,
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: .38),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'عرض النتائج',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (active > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$active',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String label,
    required String hint,
    required bool isRight,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: isFocused ? AppTheme.primaryBlue : AppTheme.neutralGray500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isFocused
                        ? AppTheme.primaryBlue
                        : AppTheme.neutralGray900,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: AppTheme.neutralGray300,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isFocused
                      ? AppTheme.primaryBlue
                      : AppTheme.neutralGray400,
                ),
                child: const Text('ر.س'),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(top: 6),
            height: 2,
            decoration: BoxDecoration(
              color: isFocused ? AppTheme.primaryBlue : AppTheme.neutralGray100,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Icon(icon, size: 15, color: AppTheme.primaryBlue),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.neutralGray800,
        ),
      ),
    ],
  );
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
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
          ),
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

// ── Search Suggestions Overlay ─────────────────────────────────────────────────

class _SuggestionsPanel extends StatelessWidget {
  final List<String> suggestions;
  final String query;
  final void Function(String) onSelect;

  const _SuggestionsPanel({
    required this.suggestions,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 6,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 44, endIndent: 16),
            itemBuilder: (context, i) {
              final s = suggestions[i];
              return InkWell(
                onTap: () => onSelect(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.neutralGray400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.neutralGray800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.north_west_rounded,
                        size: 14,
                        color: AppTheme.neutralGray400,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
