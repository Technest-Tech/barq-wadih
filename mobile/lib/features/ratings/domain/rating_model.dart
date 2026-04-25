// Rating domain models

class RatingModel {
  final int id;
  final int stars;
  final String? comment;
  final bool isApproved;
  final ({int id, String name, String? avatar}) rater;
  final ({int id, String title})? ad;
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.stars,
    this.comment,
    required this.isApproved,
    required this.rater,
    this.ad,
    required this.createdAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    final raterJson = json['rater'] as Map<String, dynamic>;
    final adJson    = json['ad'] as Map<String, dynamic>?;

    return RatingModel(
      id:         json['id'] as int,
      stars:      json['stars'] as int,
      comment:    json['comment'] as String?,
      isApproved: json['is_approved'] as bool? ?? true,
      rater: (
        id:     raterJson['id'] as int,
        name:   raterJson['name'] as String? ?? '',
        avatar: raterJson['avatar'] as String?,
      ),
      ad: adJson != null
          ? (id: adJson['id'] as int, title: adJson['title'] as String? ?? '')
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RatingSummary {
  final double avgRating;
  final int ratingCount;
  final Map<int, int> distribution; // {5: 15, 4: 5, ...}

  const RatingSummary({
    required this.avgRating,
    required this.ratingCount,
    required this.distribution,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribution'] as Map<String, dynamic>? ?? {};
    final dist    = rawDist.map(
      (k, v) => MapEntry(int.parse(k), (v as num).toInt()),
    );
    return RatingSummary(
      avgRating:   json['avg_rating'] != null
          ? double.tryParse(json['avg_rating'].toString()) ?? 0.0
          : 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      distribution: dist,
    );
  }

  /// Returns percentage (0.0–1.0) for a given star value.
  double percentageFor(int stars) {
    if (ratingCount == 0) return 0.0;
    return (distribution[stars] ?? 0) / ratingCount;
  }
}
