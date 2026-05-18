// lib/features/ads/domain/ad_model.dart

// ── Image ─────────────────────────────────────────────────────────────────────

class AdImageModel {
  final int id;
  final String imageUrl;
  final String thumbnailUrl;
  final int sortOrder;
  final int? width;
  final int? height;

  const AdImageModel({
    required this.id,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.sortOrder,
    this.width,
    this.height,
  });

  factory AdImageModel.fromJson(Map<String, dynamic> json) {
    return AdImageModel(
      id:           json['id'] as int,
      imageUrl:     json['image_url'] as String,
      thumbnailUrl: (json['thumbnail_url'] as String?) ?? json['image_url'] as String,
      sortOrder:    json['sort_order'] as int? ?? 0,
      width:        json['width'] as int?,
      height:       json['height'] as int?,
    );
  }
}

// ── Field value ───────────────────────────────────────────────────────────────

class AdFieldValueModel {
  final String fieldKey;
  final String labelAr;
  final String labelEn;
  final String fieldType;
  final dynamic value;

  const AdFieldValueModel({
    required this.fieldKey,
    required this.labelAr,
    required this.labelEn,
    required this.fieldType,
    required this.value,
  });

  factory AdFieldValueModel.fromJson(Map<String, dynamic> json) {
    return AdFieldValueModel(
      fieldKey:  json['field_key'] as String? ?? '',
      labelAr:   json['label_ar'] as String? ?? '',
      labelEn:   json['label_en'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      value:     json['value'],
    );
  }

  String get displayValue {
    if (value == null) return '—';
    if (value is bool) return value as bool ? 'نعم' : 'لا';
    if (value is List) return (value as List).join('، ');
    return value.toString();
  }
}

// ── Category field (for form rendering) ───────────────────────────────────────

class CategoryFieldModel {
  final int id;
  final String fieldKey;
  final String labelAr;
  final String labelEn;
  final String fieldType;
  final List<String> options;
  final bool isRequired;
  final String? placeholderAr;

  const CategoryFieldModel({
    required this.id,
    required this.fieldKey,
    required this.labelAr,
    required this.labelEn,
    required this.fieldType,
    required this.options,
    required this.isRequired,
    this.placeholderAr,
  });

  factory CategoryFieldModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final opts = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];
    return CategoryFieldModel(
      id:            json['id'] as int,
      fieldKey:      json['field_key'] as String,
      labelAr:       json['label_ar'] as String? ?? '',
      labelEn:       json['label_en'] as String? ?? '',
      fieldType:     json['field_type'] as String? ?? 'text',
      options:       opts,
      isRequired:    json['is_required'] as bool? ?? false,
      placeholderAr: json['placeholder_ar'] as String?,
    );
  }
}

// ── Lightweight ad for lists/feed ─────────────────────────────────────────────

typedef AdSellerSummary = ({
  int id,
  String name,
  String? avatar,
  bool isVerified,
  bool isDealer,
  double? avgRating,
  int? ratingCount,
});

class AdListModel {
  final int id;
  final String title;
  final double? price;
  final bool isNegotiable;
  final bool isFree;
  final bool priceHidden;
  final String status;
  final String statusLabel;
  final AdImageModel? primaryImage;
  final int imagesCount;
  final ({int id, String nameAr, String? icon})? category;
  final ({int id, String nameAr})? city;
  final ({int id, String nameAr})? region;
  final AdSellerSummary? seller;
  final bool isBoosted;
  final DateTime? boostedUntil;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool? canRefresh;
  final DateTime? nextRefreshAt;

  const AdListModel({
    required this.id,
    required this.title,
    this.price,
    required this.isNegotiable,
    required this.isFree,
    this.priceHidden = false,
    required this.status,
    required this.statusLabel,
    this.primaryImage,
    this.imagesCount = 1,
    this.category,
    this.city,
    this.region,
    this.seller,
    required this.isBoosted,
    this.boostedUntil,
    this.publishedAt,
    required this.createdAt,
    this.expiresAt,
    this.canRefresh,
    this.nextRefreshAt,
  });

  factory AdListModel.fromJson(Map<String, dynamic> json) {
    final catJson  = json['category'] as Map<String, dynamic>?;
    final cityJson = json['city'] as Map<String, dynamic>?;
    final regJson  = json['region'] as Map<String, dynamic>?;
    final imgJson  = json['primary_image'] as Map<String, dynamic>?;
    final userJson = json['user'] as Map<String, dynamic>?;

    return AdListModel(
      id:            json['id'] as int,
      title:         json['title'] as String,
      price:         json['price'] != null ? double.tryParse(json['price'].toString()) : null,
      isNegotiable:  json['is_negotiable'] as bool? ?? false,
      isFree:        json['is_free'] as bool? ?? false,
      priceHidden:   json['price_hidden'] as bool? ?? false,
      status:        json['status'] as String? ?? 'active',
      statusLabel:   json['status_label'] as String? ?? '',
      primaryImage:  imgJson != null ? AdImageModel.fromJson(imgJson) : null,
      imagesCount:   json['images_count'] as int? ?? (imgJson != null ? 1 : 0),
      category:      catJson != null
          ? (id: catJson['id'] as int, nameAr: catJson['name_ar'] as String? ?? '', icon: catJson['icon'] as String?)
          : null,
      city:   cityJson != null ? (id: cityJson['id'] as int, nameAr: cityJson['name_ar'] as String? ?? '') : null,
      region: regJson  != null ? (id: regJson['id'] as int,  nameAr: regJson['name_ar']  as String? ?? '') : null,
      seller: userJson != null
          ? (
              id:          userJson['id'] as int,
              name:        userJson['name'] as String? ?? '',
              avatar:      userJson['avatar'] as String?,
              isVerified:  userJson['is_verified'] as bool? ?? false,
              isDealer:    userJson['is_dealer'] as bool? ?? false,
              avgRating:   userJson['avg_rating'] != null
                  ? double.tryParse(userJson['avg_rating'].toString())
                  : null,
              ratingCount: userJson['rating_count'] as int?,
            )
          : null,
      isBoosted:   json['is_boosted'] as bool? ?? false,
      boostedUntil: json['boosted_until'] != null ? DateTime.tryParse(json['boosted_until'] as String) : null,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
      createdAt:   DateTime.parse(json['created_at'] as String),
      expiresAt:   json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      canRefresh:  json['can_refresh'] as bool?,
      nextRefreshAt: json['next_refresh_at'] != null ? DateTime.tryParse(json['next_refresh_at'] as String) : null,
    );
  }

  String get priceDisplay {
    if (isFree) return 'مجاني';
    if (priceHidden) return 'اتصل للسعر';
    if (price == null) return '—';
    return '${price!.toStringAsFixed(0)} ر.س';
  }
}

// ── Full ad detail ────────────────────────────────────────────────────────────

class AdDetailModel extends AdListModel {
  final String description;
  final List<AdImageModel> images;
  final List<AdFieldValueModel> fieldValues;
  final ({
    int id,
    String name,
    String? avatar,
    String? bio,
    bool isVerified,
    bool isDealer,
    double? avgRating,
    int? ratingCount,
    int? totalAdsCount,
    DateTime? memberSince,
  })? user;
  final String contactPhone;
  final String? contactWhatsapp;
  final bool showPhonePublicly;
  final ({int id, String nameAr})? district;
  final int viewsCount;
  final int favoritesCount;
  final bool? canBoost;

  const AdDetailModel({
    required super.id,
    required super.title,
    super.price,
    required super.isNegotiable,
    required super.isFree,
    super.priceHidden,
    required super.status,
    required super.statusLabel,
    super.primaryImage,
    super.category,
    super.city,
    super.region,
    super.seller,
    required super.isBoosted,
    super.boostedUntil,
    super.publishedAt,
    required super.createdAt,
    super.expiresAt,
    super.canRefresh,
    super.nextRefreshAt,
    required this.description,
    required this.images,
    required this.fieldValues,
    this.user,
    required this.contactPhone,
    this.contactWhatsapp,
    this.showPhonePublicly = true,
    this.district,
    required this.viewsCount,
    required this.favoritesCount,
    this.canBoost,
  });

  factory AdDetailModel.fromJson(Map<String, dynamic> json) {
    final base         = AdListModel.fromJson(json);
    final userJson     = json['user'] as Map<String, dynamic>?;
    final districtJson = json['district'] as Map<String, dynamic>?;
    return AdDetailModel(
      id:                base.id,
      title:             base.title,
      price:             base.price,
      isNegotiable:      base.isNegotiable,
      isFree:            base.isFree,
      priceHidden:       base.priceHidden,
      status:            base.status,
      statusLabel:       base.statusLabel,
      primaryImage:      base.primaryImage,
      category:          base.category,
      city:              base.city,
      region:            base.region,
      seller:            base.seller,
      isBoosted:         base.isBoosted,
      boostedUntil:      base.boostedUntil,
      publishedAt:       base.publishedAt,
      createdAt:         base.createdAt,
      expiresAt:         base.expiresAt,
      canRefresh:        base.canRefresh,
      nextRefreshAt:     base.nextRefreshAt,
      description:       json['description'] as String? ?? '',
      images:            (json['images'] as List<dynamic>? ?? [])
          .map((e) => AdImageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      fieldValues:       (json['field_values'] as List<dynamic>? ?? [])
          .map((e) => AdFieldValueModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      user:              userJson != null
          ? (
              id:            userJson['id'] as int,
              name:          userJson['name'] as String? ?? '',
              avatar:        userJson['avatar'] as String?,
              bio:           userJson['bio'] as String?,
              isVerified:    userJson['is_verified'] as bool? ?? false,
              isDealer:      userJson['is_dealer'] as bool? ?? false,
              avgRating:     userJson['avg_rating'] != null
                  ? double.tryParse(userJson['avg_rating'].toString())
                  : null,
              ratingCount:   userJson['rating_count'] as int?,
              totalAdsCount: userJson['total_ads_count'] as int?,
              memberSince:   userJson['member_since'] != null
                  ? DateTime.tryParse(userJson['member_since'] as String)
                  : null,
            )
          : null,
      contactPhone:      json['contact_phone'] as String? ?? '',
      contactWhatsapp:   json['contact_whatsapp'] as String?,
      showPhonePublicly: json['show_phone_publicly'] as bool? ?? true,
      district:          districtJson != null
          ? (id: districtJson['id'] as int, nameAr: districtJson['name_ar'] as String? ?? '')
          : null,
      viewsCount:        json['views_count'] as int? ?? 0,
      favoritesCount:    json['favorites_count'] as int? ?? 0,
      canBoost:          json['can_boost'] as bool?,
    );
  }
}
