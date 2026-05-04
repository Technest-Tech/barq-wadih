// ── Auth User Model ───────────────────────────────────────────────────────────

class AuthUser {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String role;
  final String locale;
  final bool isVerified;
  final bool isDealer;
  final bool isActive;
  final String avgRating;
  final int ratingCount;
  final int totalAdsCount;
  final int unreadNotificationsCount;
  final String? phoneVerifiedAt;
  final String? emailVerifiedAt;
  final String createdAt;

  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bio,
    required this.role,
    required this.locale,
    required this.isVerified,
    required this.isDealer,
    required this.isActive,
    required this.avgRating,
    required this.ratingCount,
    required this.totalAdsCount,
    required this.unreadNotificationsCount,
    this.phoneVerifiedAt,
    this.emailVerifiedAt,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id:                          json['id'] as int,
      name:                        json['name'] as String,
      email:                       json['email'] as String?,
      phone:                       json['phone'] as String?,
      avatarUrl:                   json['avatar_url'] as String?,
      bio:                         json['bio'] as String?,
      role:                        json['role'] as String,
      locale:                      json['locale'] as String,
      isVerified:                  json['is_verified'] as bool? ?? false,
      isDealer:                    json['is_dealer'] as bool? ?? false,
      isActive:                    json['is_active'] as bool? ?? true,
      avgRating:                   json['avg_rating'] as String? ?? '0',
      ratingCount:                 json['rating_count'] as int? ?? 0,
      totalAdsCount:               json['total_ads_count'] as int? ?? 0,
      unreadNotificationsCount:    json['unread_notifications_count'] as int? ?? 0,
      phoneVerifiedAt:             json['phone_verified_at'] as String?,
      emailVerifiedAt:             json['email_verified_at'] as String?,
      createdAt:                   json['created_at'] as String? ?? '',
    );
  }

  bool get isAdmin => role == 'admin' || role == 'super_admin';
}
