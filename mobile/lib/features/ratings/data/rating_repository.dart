import 'package:dio/dio.dart';

import '../domain/rating_model.dart';

class RatingRepository {
  final Dio _dio;
  RatingRepository(this._dio);

  // ── Get ratings for an ad ─────────────────────────────────────────────────

  Future<List<RatingModel>> fetchAdRatings(int adId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ads/$adId/ratings',
      queryParameters: {'page': page},
    );
    final data = (res.data?['data'] as List<dynamic>? ?? []);
    return data
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get ratings for a user ────────────────────────────────────────────────

  Future<List<RatingModel>> fetchUserRatings(int userId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/$userId/ratings',
      queryParameters: {'page': page},
    );
    final data = (res.data?['data'] as List<dynamic>? ?? []);
    return data
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get rating summary ────────────────────────────────────────────────────

  Future<RatingSummary> fetchUserRatingSummary(int userId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/$userId/rating-summary',
    );
    return RatingSummary.fromJson(res.data?['data'] as Map<String, dynamic>);
  }

  // ── Submit rating ─────────────────────────────────────────────────────────

  Future<RatingModel> submitRating({
    required int adId,
    required int stars,
    String? comment,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ads/$adId/ratings',
      data: {
        'stars':           stars,
        'comment':         comment,
        'pledge_accepted': true,
      },
    );
    return RatingModel.fromJson(res.data?['data'] as Map<String, dynamic>);
  }

  // ── Delete rating ─────────────────────────────────────────────────────────

  Future<void> deleteRating(int ratingId) async {
    await _dio.delete<void>('/ratings/$ratingId');
  }
}
