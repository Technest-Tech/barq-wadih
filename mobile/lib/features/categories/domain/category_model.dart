// lib/features/categories/domain/category_model.dart

/// Represents a top-level or sub-category returned by GET /api/v1/categories.
class CategoryModel {
  final int id;
  final String nameAr;
  final String nameEn;
  final String slug;
  final String? icon;
  final String? image;
  final String? descriptionAr;
  final String? descriptionEn;
  final int sortOrder;
  final bool isActive;
  final bool isFree;
  final int adsCount;
  final int fieldsCount;
  final List<CategoryModel> children;

  const CategoryModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.slug,
    this.icon,
    this.image,
    this.descriptionAr,
    this.descriptionEn,
    required this.sortOrder,
    required this.isActive,
    required this.isFree,
    required this.adsCount,
    required this.fieldsCount,
    this.children = const [],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id:            json['id'] as int,
      nameAr:        json['name_ar'] as String,
      nameEn:        json['name_en'] as String,
      slug:          json['slug'] as String,
      icon:          json['icon'] as String?,
      image:         json['image'] as String?,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      sortOrder:     json['sort_order'] as int? ?? 0,
      isActive:      json['is_active'] as bool? ?? true,
      isFree:        json['is_free'] as bool? ?? false,
      adsCount:      json['ads_count'] as int? ?? 0,
      fieldsCount:   json['fields_count'] as int? ?? 0,
      children: (json['children'] as List<dynamic>?)
              ?.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
