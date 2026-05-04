// lib/features/seller_profile/domain/seller_profile_model.dart

class SellerProfileModel {
  final int id;
  final String name;
  final String? avatar;
  final String? bio;
  final bool isVerified;
  final bool isDealer;
  final double avgRating;
  final int ratingCount;
  final Map<int, int> ratingDistribution;
  final int activeAdsCount;
  final int soldAdsCount;
  final int totalAdsCount;
  final DateTime? memberSince;
  final DateTime? lastActiveAt;

  const SellerProfileModel({
    required this.id,
    required this.name,
    this.avatar,
    this.bio,
    required this.isVerified,
    required this.isDealer,
    required this.avgRating,
    required this.ratingCount,
    required this.ratingDistribution,
    required this.activeAdsCount,
    required this.soldAdsCount,
    required this.totalAdsCount,
    this.memberSince,
    this.lastActiveAt,
  });

  factory SellerProfileModel.fromJson(Map<String, dynamic> json) {
    final dist = (json['rating_distribution'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(int.tryParse(k) ?? 0, v as int? ?? 0));
    return SellerProfileModel(
      id:               json['id'] as int,
      name:             json['name'] as String? ?? '',
      avatar:           json['avatar'] as String?,
      bio:              json['bio'] as String?,
      isVerified:       json['is_verified'] as bool? ?? false,
      isDealer:         json['is_dealer'] as bool? ?? false,
      avgRating:        double.tryParse(json['avg_rating'].toString()) ?? 0.0,
      ratingCount:      json['rating_count'] as int? ?? 0,
      ratingDistribution: dist,
      activeAdsCount:   json['active_ads_count'] as int? ?? 0,
      soldAdsCount:     json['sold_ads_count'] as int? ?? 0,
      totalAdsCount:    json['total_ads_count'] as int? ?? 0,
      memberSince:      json['member_since'] != null
          ? DateTime.tryParse(json['member_since'] as String)
          : null,
      lastActiveAt:     json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'] as String)
          : null,
    );
  }
}

class SellerReviewModel {
  final int id;
  final int stars;
  final String? comment;
  final ({int id, String name, String? avatar}) rater;
  final ({int id, String title})? ad;
  final DateTime? createdAt;

  const SellerReviewModel({
    required this.id,
    required this.stars,
    this.comment,
    required this.rater,
    this.ad,
    this.createdAt,
  });

  factory SellerReviewModel.fromJson(Map<String, dynamic> json) {
    final raterJson = json['rater'] as Map<String, dynamic>;
    final adJson    = json['ad'] as Map<String, dynamic>?;
    return SellerReviewModel(
      id:        json['id'] as int,
      stars:     json['stars'] as int? ?? 0,
      comment:   json['comment'] as String?,
      rater: (
        id:     raterJson['id'] as int,
        name:   raterJson['name'] as String? ?? '',
        avatar: raterJson['avatar'] as String?,
      ),
      ad: adJson != null
          ? (id: adJson['id'] as int, title: adJson['title'] as String? ?? '')
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
