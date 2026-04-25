// lib/features/categories/presentation/categories_screen.dart
//
// Haraj-style categories browser:
// Right sidebar with main category list (vertical scroll).
// Left side with subcategory grid (images + labels).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

import '../data/category_api.dart';
import '../domain/category_model.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int? _selectedCategoryIndex;

  // Mock subcategories for layout demonstration
  static const _mockSubs = <_MockSubCategory>[
    _MockSubCategory('سيارات', '🚗'),
    _MockSubCategory('دبابات', '🏍️'),
    _MockSubCategory('لوحات', '🔢'),
    _MockSubCategory('سيارات مصدومة', '🔧'),
    _MockSubCategory('سطحة', '🚛'),
    _MockSubCategory('تعليم قيادة', '🎓'),
    _MockSubCategory('جوالات', '📱'),
    _MockSubCategory('لابتوب', '💻'),
    _MockSubCategory('أرقام مميزة', '💳'),
    _MockSubCategory('شاشات', '🖥'),
    _MockSubCategory('طابعات', '🖨'),
    _MockSubCategory('ألعاب', '🎮'),
  ];

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('الأقسام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: cats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل الأقسام'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.refresh(categoriesProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (catList) {
          final selectedIdx = _selectedCategoryIndex ?? 0;
          final selectedCat = catList.isNotEmpty ? catList[selectedIdx] : null;

          return Row(
            children: [
              // ── Left: Subcategories Grid ────────────────────────────────────
              Expanded(
                flex: 3,
                child: Container(
                  color: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.neutralGray50,
                  child: selectedCat != null
                      ? _buildSubcategoryGrid(context, selectedCat, isDark, surfaceColor, onSurface)
                      : const Center(child: Text('اختر قسم')),
                ),
              ),

              // ── Right: Main Category List ──────────────────────────────────
              SizedBox(
                width: 110,
                child: Container(
                  color: surfaceColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: catList.length,
                    itemBuilder: (context, i) {
                      final cat = catList[i];
                      final isSelected = i == selectedIdx;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategoryIndex = i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue.withValues(alpha: isDark ? .3 : .08)
                                : Colors.transparent,
                            border: Border(
                              right: BorderSide(
                                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            cat.nameAr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : onSurface.withValues(alpha: .7),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubcategoryGrid(
    BuildContext context,
    CategoryModel category,
    bool isDark,
    Color surfaceColor,
    Color onSurface,
  ) {
    // Use real children if available, otherwise mock
    final hasChildren = category.children.isNotEmpty;
    final itemCount = hasChildren ? category.children.length : _mockSubs.length;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        final label = hasChildren ? category.children[i].nameAr : _mockSubs[i].name;
        final icon = hasChildren
            ? (category.children[i].icon ?? '📦')
            : _mockSubs[i].emoji;

        return _SubCategoryCard(
          label: label,
          icon: icon,
          isDark: isDark,
          surfaceColor: surfaceColor,
          onSurface: onSurface,
          onTap: () {
            if (hasChildren) {
              context.go('/', extra: {'categoryId': category.children[i].id});
            } else {
              context.go('/', extra: {'categoryId': category.id});
            }
          },
        );
      },
    );
  }
}

class _SubCategoryCard extends StatefulWidget {
  final String label;
  final String icon;
  final bool isDark;
  final Color surfaceColor;
  final Color onSurface;
  final VoidCallback onTap;

  const _SubCategoryCard({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.surfaceColor,
    required this.onSurface,
    required this.onTap,
  });

  @override
  State<_SubCategoryCard> createState() => _SubCategoryCardState();
}

class _SubCategoryCardState extends State<_SubCategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.white12 : AppTheme.neutralGray200,
            ),
            boxShadow: widget.isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: widget.isDark ? .2 : .06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(widget.icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockSubCategory {
  final String name;
  final String emoji;
  const _MockSubCategory(this.name, this.emoji);
}
