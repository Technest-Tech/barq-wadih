// lib/features/categories/presentation/categories_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../ads/data/ad_api.dart';
import '../data/category_api.dart';
import '../domain/category_model.dart';
import 'category_icons.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int _selectedIdx = 0;

  void _navigate(
    BuildContext context,
    CategoryModel parent,
    CategoryModel? sub,
  ) {
    ref.read(categoryNavProvider.notifier).set((
      categoryId: parent.id,
      subcategoryId: sub?.id,
    ));
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : AppTheme.neutralGray50,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'الأقسام',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: cats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _ErrorView(onRetry: () => ref.refresh(categoriesProvider)),
          data: (catList) {
            if (catList.isEmpty) {
              return const Center(child: Text('لا توجد أقسام'));
            }
            final selectedIdx = _selectedIdx.clamp(0, catList.length - 1);
            final selectedCat = catList[selectedIdx];

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Right sidebar: main categories ───────────────────────────
                _MainCategoryList(
                  categories: catList,
                  selectedIdx: selectedIdx,
                  isDark: isDark,
                  surface: surface,
                  onTap: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedIdx = i);
                  },
                ),

                // ── Left area: subcategories grid ────────────────────────────
                Expanded(
                  child: _SubcategoryGrid(
                    parent: selectedCat,
                    isDark: isDark,
                    onTap: (sub) => _navigate(context, selectedCat, sub),
                    onParentTap: () => _navigate(context, selectedCat, null),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Main category sidebar ─────────────────────────────────────────────────────

class _MainCategoryList extends StatelessWidget {
  final List<CategoryModel> categories;
  final int selectedIdx;
  final bool isDark;
  final Color surface;
  final void Function(int) onTap;

  const _MainCategoryList({
    required this.categories,
    required this.selectedIdx,
    required this.isDark,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .25 : .07),
              blurRadius: 8,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final isSelected = i == selectedIdx;
            return _SidebarItem(
              label: categories[i].nameAr,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => onTap(i),
            );
          },
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: isDark ? .25 : .09)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppTheme.primaryBlue
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .65),
          ),
        ),
      ),
    );
  }
}

// ── Subcategory grid ──────────────────────────────────────────────────────────

class _SubcategoryGrid extends StatefulWidget {
  final CategoryModel parent;
  final bool isDark;
  final void Function(CategoryModel sub) onTap;
  final VoidCallback onParentTap;

  const _SubcategoryGrid({
    required this.parent,
    required this.isDark,
    required this.onTap,
    required this.onParentTap,
  });

  @override
  State<_SubcategoryGrid> createState() => _SubcategoryGridState();
}

class _SubcategoryGridState extends State<_SubcategoryGrid> {
  // Third-level drill-down (e.g. طيور → حمام/دجاج/بط). Null = browsing the
  // parent's direct subcategories.
  CategoryModel? _drilled;

  @override
  void didUpdateWidget(_SubcategoryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parent.id != widget.parent.id) _drilled = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final level = _drilled ?? widget.parent;
    final subs = level.children;

    if (subs.isEmpty) {
      // No children → the category itself is the leaf
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: widget.parent.nameAr),
            const SizedBox(height: 12),
            _BadgeTile(
              label: widget.parent.nameAr,
              slug: widget.parent.slug,
              index: 0,
              isDark: isDark,
              onTap: widget.onParentTap,
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: _drilled == null
                ? _SectionHeader(title: widget.parent.nameAr)
                : _DrillHeader(
                    title: _drilled!.nameAr,
                    parentTitle: widget.parent.nameAr,
                    onBack: () => setState(() => _drilled = null),
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildBuilderDelegate((_, i) {
              final sub = subs[i];
              final drillable = _drilled == null && sub.children.isNotEmpty;
              return _BadgeTile(
                label: sub.nameAr,
                slug: sub.slug,
                index: i,
                isDark: isDark,
                showChevron: drillable,
                onTap: () {
                  if (drillable) {
                    setState(() => _drilled = sub);
                  } else {
                    widget.onTap(sub);
                  }
                },
              );
            }, childCount: subs.length),
          ),
        ),
      ],
    );
  }
}

/// Header shown when drilled into a third-level group, with a back affordance.
class _DrillHeader extends StatelessWidget {
  final String title;
  final String parentTitle;
  final VoidCallback onBack;
  const _DrillHeader({
    required this.title,
    required this.parentTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: _SectionHeader(title: title)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .8),
          ),
        ),
      ],
    );
  }
}

// ── Badge tile ────────────────────────────────────────────────────────────────

class _BadgeTile extends StatefulWidget {
  final String label;
  final String slug;
  final int index;
  final bool isDark;
  final bool showChevron;
  final VoidCallback onTap;

  const _BadgeTile({
    required this.label,
    required this.slug,
    required this.index,
    required this.isDark,
    this.showChevron = false,
    required this.onTap,
  });

  @override
  State<_BadgeTile> createState() => _BadgeTileState();
}

class _BadgeTileState extends State<_BadgeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  // 8-colour palette: (gradient start, gradient end, text)
  static const _palette = [
    (Color(0xFF1565C0), Color(0xFF1E88E5), Colors.white),
    (Color(0xFF2E7D32), Color(0xFF43A047), Colors.white),
    (Color(0xFFE65100), Color(0xFFEF6C00), Colors.white),
    (Color(0xFF6A1B9A), Color(0xFF8E24AA), Colors.white),
    (Color(0xFFC62828), Color(0xFFE53935), Colors.white),
    (Color(0xFF00695C), Color(0xFF00897B), Colors.white),
    (Color(0xFFAD1457), Color(0xFFD81B60), Colors.white),
    (Color(0xFF37474F), Color(0xFF546E7A), Colors.white),
  ];

  (Color, Color, Color) get _colors => _palette[widget.index % _palette.length];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (from, to, textColor) = _colors;
    final darkFrom = from.withValues(alpha: .55);
    final darkTo = to.withValues(alpha: .45);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isDark ? [darkFrom, darkTo] : [from, to],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isDark ? darkFrom : from).withValues(
                      alpha: .35,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Always render the white Lucide glyph on the coloured tile —
                  // the tile itself is the gradient, so we must not nest the
                  // coloured gradient-tile SVG (image) inside another gradient.
                  Icon(categoryIcon(widget.slug), color: textColor, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.showChevron)
              Positioned(
                top: 6,
                left: 6,
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 14,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('تعذّر تحميل الأقسام'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
