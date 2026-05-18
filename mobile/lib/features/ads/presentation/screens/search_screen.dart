import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
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
}

final _searchNotifier = NotifierProvider.autoDispose<_SearchNotifier, _SearchState>(_SearchNotifier.new);

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

  @override
  Widget build(BuildContext context) {
    final searchState  = ref.watch(_searchNotifier);
    final filter       = searchState.filter;
    final hasQuery     = filter.q?.isNotEmpty ?? false;

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
