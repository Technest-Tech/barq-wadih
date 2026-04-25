// lib/features/regions/domain/region_model.dart

/// Represents a Saudi region returned by GET /api/v1/regions.
class RegionModel {
  final int id;
  final String nameAr;
  final String nameEn;
  final String slug;
  final int sortOrder;
  final int citiesCount;

  const RegionModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.slug,
    required this.sortOrder,
    required this.citiesCount,
  });

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    return RegionModel(
      id:          json['id'] as int,
      nameAr:      json['name_ar'] as String,
      nameEn:      json['name_en'] as String,
      slug:        json['slug'] as String,
      sortOrder:   json['sort_order'] as int? ?? 0,
      citiesCount: json['cities_count'] as int? ?? 0,
    );
  }
}

/// Represents a city returned by GET /api/v1/regions/{slug}/cities.
class CityModel {
  final int id;
  final String nameAr;
  final String nameEn;
  final String slug;
  final double? latitude;
  final double? longitude;
  final int adsCount;
  final RegionModel? region;

  const CityModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.slug,
    this.latitude,
    this.longitude,
    required this.adsCount,
    this.region,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id:        json['id'] as int,
      nameAr:    json['name_ar'] as String,
      nameEn:    json['name_en'] as String,
      slug:      json['slug'] as String,
      latitude:  (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      adsCount:  json['ads_count'] as int? ?? 0,
      region: json['region'] != null ? RegionModel.fromJson(json['region'] as Map<String, dynamic>) : null,
    );
  }
}
