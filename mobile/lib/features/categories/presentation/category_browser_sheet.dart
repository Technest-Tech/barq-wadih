// lib/features/categories/presentation/category_browser_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../data/category_api.dart';
import '../domain/category_model.dart';

Future<CategoryModel?> showCategoryBrowserSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<CategoryModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CategoryBrowserSheet(),
  );
}

const _kAccentColors = [
  Color(0xFF6C63FF),
  Color(0xFF00B4D8),
  Color(0xFFFF6B6B),
  Color(0xFF2EC4B6),
  Color(0xFFFF9F1C),
  Color(0xFF8338EC),
  Color(0xFF06D6A0),
  Color(0xFFEF476F),
  Color(0xFF118AB2),
  Color(0xFFFFD166),
  Color(0xFF073B4C),
  Color(0xFFE63946),
];

// ── Sheet ─────────────────────────────────────────────────────────────────────

class CategoryBrowserSheet extends ConsumerStatefulWidget {
  const CategoryBrowserSheet({super.key});

  @override
  ConsumerState<CategoryBrowserSheet> createState() =>
      _CategoryBrowserSheetState();
}

class _CategoryBrowserSheetState
    extends ConsumerState<CategoryBrowserSheet> {
  CategoryModel? _selected;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_SearchHit> _searchAll(List<CategoryModel> cats) {
    final q = _query.trim();
    if (q.isEmpty) return [];
    final hits = <_SearchHit>[];
    for (final cat in cats) {
      if (_matches(cat.nameAr, q) || _matches(cat.nameEn, q)) {
        hits.add(_SearchHit(cat: cat, parent: null));
      }
      for (final child in cat.children) {
        if (_matches(child.nameAr, q) || _matches(child.nameEn, q)) {
          hits.add(_SearchHit(cat: child, parent: cat));
        }
      }
    }
    return hits;
  }

  List<CategoryModel> _searchChildren(List<CategoryModel> children) {
    final q = _query.trim();
    if (q.isEmpty) return children;
    return children
        .where((c) => _matches(c.nameAr, q) || _matches(c.nameEn, q))
        .toList();
  }

  bool _matches(String text, String q) =>
      text.toLowerCase().contains(q.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(categoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    if (_selected != null)
                      IconButton(
                        onPressed: () =>
                            setState(() { _selected = null; _query = ''; _searchCtrl.clear(); }),
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.neutralGray100,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(8),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selected != null ? _selected!.nameAr : 'اختر القسم',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.neutralGray900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.neutralGray100,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.rtl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: _selected != null
                        ? 'بحث في ${_selected!.nameAr}...'
                        : 'بحث في الأقسام...',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: const TextStyle(
                      color: AppTheme.neutralGray500,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.neutralGray400, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: AppTheme.neutralGray400),
                            onPressed: () =>
                                setState(() { _query = ''; _searchCtrl.clear(); }),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.neutralGray50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.neutralGray200, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 1.5),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppTheme.neutralGray100),

              // Content
              Expanded(
                child: async.when(
                  loading: () => _Skeleton(controller: scrollCtrl),
                  error: (e, _) => _ErrorView(
                    onRetry: () => ref.refresh(categoriesProvider),
                  ),
                  data: (cats) {
                    // Subcategory view
                    if (_selected != null) {
                      final children = _searchChildren(_selected!.children);
                      return _ChildrenListView(
                        parent: _selected!,
                        children: children,
                        query: _query,
                        controller: scrollCtrl,
                        onSelect: (c) => Navigator.pop(context, c),
                        onSelectParent: () =>
                            Navigator.pop(context, _selected),
                      );
                    }

                    // Search mode — flat results across all
                    if (_query.trim().isNotEmpty) {
                      final hits = _searchAll(cats);
                      return _SearchResultsView(
                        hits: hits,
                        controller: scrollCtrl,
                        onSelect: (hit) {
                          if (hit.parent == null &&
                              hit.cat.children.isNotEmpty) {
                            setState(() {
                              _selected = hit.cat;
                              _query = '';
                              _searchCtrl.clear();
                            });
                          } else {
                            Navigator.pop(context, hit.cat);
                          }
                        },
                      );
                    }

                    // Default — top-level list
                    return _TopLevelListView(
                      categories: cats,
                      controller: scrollCtrl,
                      onTap: (cat) {
                        if (cat.children.isEmpty) {
                          Navigator.pop(context, cat);
                        } else {
                          setState(() => _selected = cat);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _SearchHit {
  final CategoryModel cat;
  final CategoryModel? parent;
  const _SearchHit({required this.cat, required this.parent});
}

// ── Top-level list ─────────────────────────────────────────────────────────────

class _TopLevelListView extends StatelessWidget {
  final List<CategoryModel> categories;
  final ScrollController controller;
  final ValueChanged<CategoryModel> onTap;

  const _TopLevelListView({
    required this.categories,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 52,
        endIndent: 16,
        color: AppTheme.neutralGray100,
      ),
      itemBuilder: (_, i) {
        final cat = categories[i];
        final color = _kAccentColors[i % _kAccentColors.length];
        return _CategoryTile(
          name: cat.nameAr,
          color: color,
          childCount: cat.children.length,
          onTap: () => onTap(cat),
        );
      },
    );
  }
}

// ── Children list ──────────────────────────────────────────────────────────────

class _ChildrenListView extends StatelessWidget {
  final CategoryModel parent;
  final List<CategoryModel> children;
  final String query;
  final ScrollController controller;
  final ValueChanged<CategoryModel> onSelect;
  final VoidCallback onSelectParent;

  const _ChildrenListView({
    required this.parent,
    required this.children,
    required this.query,
    required this.controller,
    required this.onSelect,
    required this.onSelectParent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (query.isEmpty)
          _AllParentTile(parent: parent, onTap: onSelectParent),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'لا توجد نتائج',
                style: TextStyle(color: AppTheme.neutralGray500),
              ),
            ),
          )
        else
          ...children.asMap().entries.map((e) {
            final color = _kAccentColors[e.key % _kAccentColors.length];
            return Column(
              children: [
                _CategoryTile(
                  name: e.value.nameAr,
                  color: color,
                  childCount: 0,
                  onTap: () => onSelect(e.value),
                ),
                const Divider(
                  height: 1,
                  indent: 52,
                  endIndent: 16,
                  color: AppTheme.neutralGray100,
                ),
              ],
            );
          }),
      ],
    );
  }
}

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final List<_SearchHit> hits;
  final ScrollController controller;
  final ValueChanged<_SearchHit> onSelect;

  const _SearchResultsView({
    required this.hits,
    required this.controller,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off_rounded, size: 48, color: AppTheme.neutralGray300),
            SizedBox(height: 12),
            Text('لا توجد نتائج',
                style: TextStyle(color: AppTheme.neutralGray500, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hits.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 52,
        endIndent: 16,
        color: AppTheme.neutralGray100,
      ),
      itemBuilder: (_, i) {
        final hit = hits[i];
        final color = _kAccentColors[i % _kAccentColors.length];
        return _SearchResultTile(
          hit: hit,
          color: color,
          onTap: () => onSelect(hit),
        );
      },
    );
  }
}

// ── Tile widgets ───────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String name;
  final Color color;
  final int childCount;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.color,
    required this.childCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray900,
                ),
              ),
            ),
            if (childCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$childCount',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_back_ios, size: 12, color: AppTheme.neutralGray400),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllParentTile extends StatelessWidget {
  final CategoryModel parent;
  final VoidCallback onTap;

  const _AllParentTile({required this.parent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'كل ${parent.nameAr}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                Icon(Icons.arrow_back_ios,
                    size: 12, color: AppTheme.primaryBlue),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 52, endIndent: 16,
            color: AppTheme.neutralGray100),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchHit hit;
  final Color color;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.hit,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isParentWithChildren =
        hit.parent == null && hit.cat.children.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hit.cat.nameAr,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutralGray900,
                    ),
                  ),
                  if (hit.parent != null)
                    Text(
                      hit.parent!.nameAr,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.neutralGray500,
                      ),
                    ),
                ],
              ),
            ),
            if (isParentWithChildren) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${hit.cat.children.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_back_ios,
                  size: 12, color: AppTheme.neutralGray400),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  final ScrollController controller;
  const _Skeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      separatorBuilder: (_, __) => const Divider(
          height: 1, indent: 52, endIndent: 16, color: AppTheme.neutralGray100),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: AppTheme.neutralGray200, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Container(
              height: 14,
              width: 120 + (i % 3) * 30.0,
              decoration: BoxDecoration(
                color: AppTheme.neutralGray100,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ──────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('فشل تحميل الأقسام',
              style: TextStyle(color: AppTheme.neutralGray600)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
