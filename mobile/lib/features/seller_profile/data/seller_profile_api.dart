// lib/features/seller_profile/data/seller_profile_api.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../ads/domain/ad_model.dart';
import '../domain/seller_profile_model.dart';

class SellerProfileRepository {
  final Dio _dio;
  const SellerProfileRepository(this._dio);

  Future<SellerProfileModel> getProfile(int userId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/$userId');
      final data = response.data!['data'] as Map<String, dynamic>;
      return SellerProfileModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل بيانات البائع',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<({List<AdListModel> ads, bool hasMore, int total})> getAds(int userId, {int page = 1}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/$userId/ads',
        queryParameters: {'page': page},
      );
      final body = response.data!;
      final list = body['data'] as List<dynamic>;
      final meta = body['meta'] as Map<String, dynamic>?;
      final ads = list.map((e) => AdListModel.fromJson(e as Map<String, dynamic>)).toList();
      final hasMore = meta != null
          ? (meta['current_page'] as int? ?? 1) < (meta['last_page'] as int? ?? 1)
          : false;
      final total = meta?['total'] as int? ?? ads.length;
      return (ads: ads, hasMore: hasMore, total: total);
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل إعلانات البائع',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<SellerReviewModel>> getReviews(int userId, {int page = 1}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/$userId/ratings',
        queryParameters: {'page': page},
      );
      final list = response.data!['data'] as List<dynamic>;
      return list.map((e) => SellerReviewModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل تقييمات البائع',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

final sellerProfileRepositoryProvider = Provider<SellerProfileRepository>((ref) {
  return SellerProfileRepository(ref.watch(dioProvider));
});

final sellerProfileProvider =
    FutureProvider.family<SellerProfileModel, int>((ref, userId) {
  return ref.read(sellerProfileRepositoryProvider).getProfile(userId);
});

final sellerAdsProvider =
    FutureProvider.family<({List<AdListModel> ads, bool hasMore, int total}), int>((ref, userId) {
  return ref.read(sellerProfileRepositoryProvider).getAds(userId);
});

final sellerReviewsProvider =
    FutureProvider.family<List<SellerReviewModel>, int>((ref, userId) {
  return ref.read(sellerProfileRepositoryProvider).getReviews(userId);
});
