// lib/features/categories/presentation/category_browser_sheet.dart
//
// Usage:
//   final category = await showCategoryBrowserSheet(context, ref);
//   if (category != null) { /* user selected a category or subcategory */ }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_api.dart';
import '../domain/category_model.dart';

/// Shows a full-height bottom sheet for browsing categories.
/// Returns the selected [CategoryModel] (top-level or child) or null.
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

class CategoryBrowserSheet extends ConsumerStatefulWidget {
  const CategoryBrowserSheet({super.key});

  @override
  ConsumerState<CategoryBrowserSheet> createState() =>
      _CategoryBrowserSheetState();
}

class _CategoryBrowserSheetState extends ConsumerState<CategoryBrowserSheet> {
  CategoryModel? _selected; // top-level category whose children are showing

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_selected != null)
                      IconButton(
                        onPressed: () => setState(() => _selected = null),
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                        tooltip: 'رجوع',
                      ),
                    Expanded(
                      child: Text(
                        _selected != null ? _selected!.nameAr : 'اختر القسم',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: categoriesAsync.when(
                  loading: () => const _CategoryGridSkeleton(),
                  error: (e, _) => _ErrorView(
                    message: 'فشل تحميل الأقسام',
                    onRetry: () => ref.refresh(categoriesProvider),
                  ),
                  data: (categories) {
                    // If a parent is selected, show its children
                    if (_selected != null) {
                      return _ChildrenList(
                        parent: _selected!,
                        onSelect: (child) => Navigator.pop(context, child),
                      );
                    }
                    // Otherwise show top-level category grid
                    return _TopLevelGrid(
                      categories: categories,
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

// ── Top-level grid ────────────────────────────────────────────────────────────

class _TopLevelGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onTap;

  const _TopLevelGrid({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        return InkWell(
          onTap: () => onTap(cat),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cat.icon ?? '📦',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 8),
                Text(
                  cat.nameAr,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cat.children.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_back_ios,
                    size: 10,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Children list ─────────────────────────────────────────────────────────────

class _ChildrenList extends StatelessWidget {
  final CategoryModel parent;
  final ValueChanged<CategoryModel> onSelect;

  const _ChildrenList({required this.parent, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Prepend "All in [parent]" option
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          title: Text(
            'كل ${parent.nameAr}',
            style: const TextStyle(fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl,
          ),
          trailing: Icon(Icons.arrow_back_ios, size: 14, color: theme.colorScheme.primary),
          onTap: () => onSelect(parent),
        ),
        const Divider(height: 1, indent: 16),
        ...parent.children.map((child) => ListTile(
          title: Text(child.nameAr, textDirection: TextDirection.rtl),
          trailing: Icon(Icons.arrow_back_ios, size: 14, color: theme.colorScheme.outline),
          onTap: () => onSelect(child),
        )),
      ],
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: List.generate(
        9,
        (_) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
