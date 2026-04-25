import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../categories/data/category_api.dart';
import '../../../categories/domain/category_model.dart';
import '../../../regions/data/region_api.dart';
import '../../../regions/domain/region_model.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';
import '../widgets/ad_card.dart';

// ── Search filter state ───────────────────────────────────────────────────────

class _SearchState {
  final String q;
  final AdsFilter filter;
  const _SearchState({this.q = '', this.filter = const AdsFilter()});
  _SearchState copyWith({String? q, AdsFilter? filter}) =>
      _SearchState(q: q ?? this.q, filter: filter ?? this.filter);
}

class _SearchNotifier extends Notifier<_SearchState> {
  @override
  _SearchState build() => const _SearchState();
  void setQuery(String q) => state = state.copyWith(
    q: q,
    filter: state.filter.copyWith(q: q, page: 1),
  );
  void applyFilter(AdsFilter filter) => state = state.copyWith(filter: filter.copyWith(q: state.q, page: 1));
  void reset()  => state = _SearchState(filter: AdsFilter(q: state.q));
  int get activeFilterCount => [
    state.filter.categoryId,
    state.filter.cityId,
    state.filter.priceMin,
    state.filter.priceMax,
  ].where((v) => v != null).length;
}

final _searchNotifier = NotifierProvider<_SearchNotifier, _SearchState>(_SearchNotifier.new);

// ── Recent Searches ───────────────────────────────────────────────────────────

const _recentKey = 'recent_searches';
const _maxRecent = 10;

Future<List<String>> _loadRecent() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_recentKey) ?? [];
}

Future<void> _saveSearch(String term) async {
  if (term.trim().isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_recentKey) ?? [];
  list.remove(term);
  list.insert(0, term);
  if (list.length > _maxRecent) list.removeLast();
  await prefs.setStringList(_recentKey, list);
}

Future<void> _clearRecent() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_recentKey);
}

// ── Search Screen ─────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus      = FocusNode();
  Timer?  _debounce;
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    _loadRecent().then((r) => setState(() => _recent = r));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(_searchNotifier.notifier).setQuery(value.trim());
    });
  }

  Future<void> _submitSearch(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    _focus.unfocus();
    await _saveSearch(trimmed);
    ref.read(_searchNotifier.notifier).setQuery(trimmed);
    setState(() {
      _recent = [trimmed, ..._recent.where((r) => r != trimmed).take(_maxRecent - 1)];
    });
  }

  void _tapRecent(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: term.length));
    _submitSearch(term);
  }

  Future<void> _clearAll() async {
    await _clearRecent();
    setState(() => _recent = []);
  }

  void _clearText() {
    _controller.clear();
    ref.read(_searchNotifier.notifier).setQuery('');
    _focus.requestFocus();
  }

  Future<void> _openFilters() async {
    final currentState = ref.read(_searchNotifier);
    final result = await showModalBottomSheet<AdsFilter?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(currentFilter: currentState.filter),
    );
    if (result != null) {
      ref.read(_searchNotifier.notifier).applyFilter(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState  = ref.watch(_searchNotifier);
    final filter       = searchState.filter;
    final hasQuery     = filter.q?.isNotEmpty ?? false;
    final activeCount  = ref.read(_searchNotifier.notifier).activeFilterCount;

    final resultsState = hasQuery ? ref.watch(searchProvider(filter)) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppTheme.neutralGray900,
          onPressed: () => context.pop(),
        ),
        title: _SearchBar(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          onSubmitted: _submitSearch,
          onClear: _clearText,
        ),
        actions: [
          // Filter icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: activeCount > 0 ? AppTheme.primaryBlue : AppTheme.neutralGray600,
                onPressed: _openFilters,
              ),
              if (activeCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: !hasQuery
          ? _RecentSearches(
              recent: _recent,
              onTap: _tapRecent,
              onClearAll: _clearAll,
              onRemove: (term) async {
                final list = List<String>.from(_recent)..remove(term);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList(_recentKey, list);
                setState(() => _recent = list);
              },
            )
          : resultsState!.when(
              loading: () => const _SearchLoadingList(),
              error: (e, _) => _SearchError(
                query: filter.q ?? '',
                onRetry: () => ref.invalidate(searchProvider(filter)),
              ),
              data: (result) => result.ads.isEmpty
                  ? _EmptyResults(query: filter.q ?? '')
                  : _SearchResultsList(ads: result.ads, total: result.total),
            ),
    );
  }
}

// ── Search Input ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller, required this.focusNode,
    required this.onChanged, required this.onSubmitted, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(color: AppTheme.neutralGray100, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 15, color: AppTheme.neutralGray900),
        decoration: InputDecoration(
          hintText: 'ابحث عن كل شيء...',
          hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
          hintTextDirection: TextDirection.rtl,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.neutralGray500, size: 20),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.cancel_rounded, color: AppTheme.neutralGray500, size: 18),
                  )
                : const SizedBox.shrink(),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  final AdsFilter currentFilter;
  const _FilterSheet({required this.currentFilter});

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late int?    _categoryId;
  late int?    _regionId;
  late int?    _cityId;
  late String  _sort;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  List<CategoryModel> _categories = [];
  List<RegionModel>   _regions    = [];
  List<CityModel>     _cities     = [];
  bool _loadingCities = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.currentFilter.categoryId;
    _regionId   = widget.currentFilter.regionId;
    _cityId     = widget.currentFilter.cityId;
    _sort       = widget.currentFilter.sort;
    _minCtrl.text = widget.currentFilter.priceMin?.toStringAsFixed(0) ?? '';
    _maxCtrl.text = widget.currentFilter.priceMax?.toStringAsFixed(0) ?? '';

    _loadData();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final cats    = await ref.read(categoriesProvider.future);
      final regions = await ref.read(regionsProvider.future);
      if (mounted) setState(() { _categories = cats; _regions = regions; });

      if (_regionId != null) {
        final region = regions.firstWhere((r) => r.id == _regionId, orElse: () => regions.first);
        await _loadCities(region.slug);
      }
    } catch (_) {}
  }

  Future<void> _loadCities(String slug) async {
    setState(() => _loadingCities = true);
    try {
      final cities = await ref.read(citiesProvider(slug).future);
      if (mounted) setState(() { _cities = cities; _loadingCities = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  void _apply() {
    final filter = AdsFilter(
      q:          widget.currentFilter.q,
      categoryId: _categoryId,
      regionId:   _regionId,
      cityId:     _cityId,
      sort:       _sort,
      priceMin:   _minCtrl.text.isNotEmpty ? double.tryParse(_minCtrl.text) : null,
      priceMax:   _maxCtrl.text.isNotEmpty ? double.tryParse(_maxCtrl.text) : null,
    );
    Navigator.pop(context, filter);
  }

  void _reset() => Navigator.pop(context, const AdsFilter());

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.neutralGray200, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text('الفلاتر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('مسح الكل', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
                children: [

                  // ── Category ──────────────────────────────────────────────
                  _FilterSection(title: 'التصنيف', icon: Icons.grid_view_rounded, child:
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _Chip(label: 'الكل', active: _categoryId == null,
                          onTap: () => setState(() => _categoryId = null)),
                        ..._categories.map((c) => _Chip(
                          icon: c.icon,
                          label: c.nameAr,
                          active: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = _categoryId == c.id ? null : c.id),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Region ────────────────────────────────────────────────
                  _FilterSection(title: 'المنطقة', icon: Icons.map_rounded, child:
                    _regions.isEmpty
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
                          ))
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              _Chip(label: 'الكل', active: _regionId == null, onTap: () => setState(() {
                                _regionId = null; _cityId = null; _cities = [];
                              })),
                              ..._regions.map((r) => _Chip(
                                label: r.nameAr,
                                active: _regionId == r.id,
                                onTap: () {
                                  setState(() { _regionId = r.id; _cityId = null; });
                                  _loadCities(r.slug);
                                },
                              )),
                            ],
                          ),
                  ),

                  // ── City (only when region selected) ─────────────────────
                  if (_regionId != null) ...[
                    const SizedBox(height: 20),
                    _FilterSection(title: 'المدينة', icon: Icons.location_city_rounded, child:
                      _loadingCities
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
                            ))
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: [
                                _Chip(label: 'الكل', active: _cityId == null,
                                  onTap: () => setState(() => _cityId = null)),
                                ..._cities.map((c) => _Chip(
                                  label: c.nameAr,
                                  active: _cityId == c.id,
                                  onTap: () => setState(() => _cityId = _cityId == c.id ? null : c.id),
                                )),
                              ],
                            ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Price Range ───────────────────────────────────────────
                  _FilterSection(title: 'نطاق السعر (ر.س)', icon: Icons.payments_outlined, child:
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: _minCtrl,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          decoration: _inputDec(hint: 'من'),
                        )),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('–', style: TextStyle(color: AppTheme.neutralGray500, fontWeight: FontWeight.w700, fontSize: 18)),
                        ),
                        Expanded(child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          decoration: _inputDec(hint: 'إلى'),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Sort ──────────────────────────────────────────────────
                  _FilterSection(title: 'الترتيب', icon: Icons.sort_rounded, child:
                    Column(
                      children: [
                        _SortOption(label: '⭐ الأنسب', value: 'relevance', groupValue: _sort, onChanged: (v) => setState(() => _sort = v!)),
                        _SortOption(label: '🕒 الأحدث', value: 'newest', groupValue: _sort, onChanged: (v) => setState(() => _sort = v!)),
                        _SortOption(label: '💰 أقل سعر', value: 'price_asc', groupValue: _sort, onChanged: (v) => setState(() => _sort = v!)),
                        _SortOption(label: '💸 أعلى سعر', value: 'price_desc', groupValue: _sort, onChanged: (v) => setState(() => _sort = v!)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Apply button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('تطبيق الفلاتر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500),
    filled: true,
    fillColor: AppTheme.neutralGray100,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
  );
}

// ── Shared filter widgets ─────────────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _FilterSection({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.neutralGray900)),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryBlue.withValues(alpha: .1) : AppTheme.neutralGray100,
          border: Border.all(color: active ? AppTheme.primaryBlue : Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppTheme.primaryBlue : AppTheme.neutralGray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label, value, groupValue;
  final ValueChanged<String?> onChanged;
  const _SortOption({required this.label, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      activeColor: AppTheme.primaryBlue,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Recent Searches ───────────────────────────────────────────────────────────

class _RecentSearches extends StatelessWidget {
  final List<String> recent;
  final ValueChanged<String> onTap;
  final VoidCallback onClearAll;
  final ValueChanged<String> onRemove;

  const _RecentSearches({required this.recent, required this.onTap, required this.onClearAll, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 64, color: AppTheme.neutralGray200),
            SizedBox(height: 12),
            Text('ابحث في آلاف الإعلانات', style: TextStyle(fontSize: 16, color: AppTheme.neutralGray500, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('عمليات البحث الأخيرة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.neutralGray500)),
              GestureDetector(
                onTap: onClearAll,
                child: const Text('مسح الكل', style: TextStyle(fontSize: 13, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ...recent.map((term) => ListTile(
          leading: const Icon(Icons.history_rounded, color: AppTheme.neutralGray500, size: 20),
          title: Text(term, style: const TextStyle(fontSize: 14, color: AppTheme.neutralGray900)),
          trailing: GestureDetector(
            onTap: () => onRemove(term),
            child: const Icon(Icons.close_rounded, color: AppTheme.neutralGray500, size: 18),
          ),
          onTap: () => onTap(term),
          dense: true,
        )),
      ],
    );
  }
}

// ── Results List ──────────────────────────────────────────────────────────────

class _SearchResultsList extends StatelessWidget {
  final List<AdListModel> ads;
  final int total;
  const _SearchResultsList({required this.ads, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '$total نتيجة',
            style: const TextStyle(fontSize: 13, color: AppTheme.neutralGray500, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ads.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AdCard(ad: ads[i], onTap: () => context.push(AppRoutes.adDetailPath(ads[i].id))),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading / Empty / Error ───────────────────────────────────────────────────

class _SearchLoadingList extends StatelessWidget {
  const _SearchLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 100,
          decoration: BoxDecoration(color: AppTheme.neutralGray100, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppTheme.neutralGray100, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.neutralGray500),
          ),
          const SizedBox(height: 16),
          Text('لا توجد نتائج لـ "$query"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.neutralGray900)),
          const SizedBox(height: 8),
          const Text('جرّب كلمات مختلفة أو تصفح الأقسام',
              style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500)),
        ],
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  final String query;
  final VoidCallback onRetry;
  const _SearchError({required this.query, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.neutralGray500),
          const SizedBox(height: 12),
          const Text('تعذّر إجراء البحث',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.neutralGray900)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
