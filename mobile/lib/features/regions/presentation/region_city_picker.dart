// lib/features/regions/presentation/region_city_picker.dart
//
// Usage:
//   final result = await showRegionCityPicker(context, ref, isMultiSelect: true);
//   if (result != null && result.isNotEmpty) {
//     // result is List<CityModel>
//   }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/region_api.dart';
import '../domain/region_model.dart';
import '../../../../core/theme/app_theme.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<List<CityModel>?> showRegionCityPicker(
  BuildContext context,
  WidgetRef ref, {
  bool isMultiSelect = false,
  List<CityModel>? initialSelection,
}) {
  return showModalBottomSheet<List<CityModel>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CityMultiSelectSheet(isMultiSelect: isMultiSelect, initialSelection: initialSelection),
  );
}

// ── Picker widget ─────────────────────────────────────────────────────────────

class _CityMultiSelectSheet extends ConsumerStatefulWidget {
  final bool isMultiSelect;
  final List<CityModel>? initialSelection;
  const _CityMultiSelectSheet({
    required this.isMultiSelect,
    this.initialSelection,
  });

  @override
  ConsumerState<_CityMultiSelectSheet> createState() => _CityMultiSelectSheetState();
}

class _CityMultiSelectSheetState extends ConsumerState<_CityMultiSelectSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final Set<int> _selectedCityIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialSelection != null) {
      _selectedCityIds.addAll(widget.initialSelection!.map((c) => c.id));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onConfirm(List<CityModel> allCities) {
    if (_selectedCityIds.isEmpty) {
      Navigator.pop(context, <CityModel>[]);
      return;
    }
    final selected = allCities.where((c) => _selectedCityIds.contains(c.id)).toList();
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final citiesAsync = ref.watch(allCitiesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: (widget.isMultiSelect && _selectedCityIds.isNotEmpty)
                          ? TextButton(
                              onPressed: () => setState(() => _selectedCityIds.clear()),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('إلغاء الكل', style: TextStyle(fontSize: 14, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                            )
                          : const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.isMultiSelect ? 'اختر المدن' : 'اختر المدينة',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.neutralGray900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.neutralGray100,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.neutralGray700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: const TextStyle(color: AppTheme.neutralGray900),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مدينة...',
                      hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.neutralGray400),
                      filled: true,
                      fillColor: AppTheme.neutralGray50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppTheme.neutralGray100),

              // List
              Expanded(
                child: citiesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text('فشل في تحميل المدن', style: theme.textTheme.titleMedium),
                        TextButton(
                          onPressed: () => ref.refresh(allCitiesProvider),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                  data: (cities) {
                    final filtered = cities.where((c) {
                      if (_searchQuery.isEmpty) return true;
                      return c.nameAr.toLowerCase().contains(_searchQuery) ||
                             c.nameEn.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'لم يتم العثور على مدن',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: AppTheme.neutralGray500),
                        ),
                      );
                    }

                    return Directionality(
                      textDirection: TextDirection.rtl,
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.neutralGray100),
                        itemBuilder: (_, i) {
                          final city = filtered[i];
                          final isSelected = _selectedCityIds.contains(city.id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (widget.isMultiSelect) {
                                  if (isSelected) {
                                    _selectedCityIds.remove(city.id);
                                  } else {
                                    _selectedCityIds.add(city.id);
                                  }
                                } else {
                                  _selectedCityIds.clear();
                                  _selectedCityIds.add(city.id);
                                  _onConfirm(cities); // Auto confirm on single select
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: widget.isMultiSelect ? BoxShape.rectangle : BoxShape.circle,
                                      borderRadius: widget.isMultiSelect ? BorderRadius.circular(6) : null,
                                      color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryBlue : AppTheme.neutralGray200,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      city.nameAr,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: AppTheme.neutralGray900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Confirm Button (Only for multi-select)
              if (widget.isMultiSelect)
                citiesAsync.maybeWhen(
                  data: (cities) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.neutralGray100)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => _onConfirm(cities),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            _selectedCityIds.isEmpty
                                ? 'تأكيد'
                                : 'تأكيد (${_selectedCityIds.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
    );
  }
}
