import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../ads/domain/ad_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class FavoriteRepository {
  final Dio _dio;
  FavoriteRepository(this._dio);

  Future<bool> toggleFavorite(int adId) async {
    final res = await _dio.post<Map<String, dynamic>>('/ads/$adId/favorite');
    return res.data?['data']?['is_favorited'] as bool? ?? false;
  }

  Future<bool> checkStatus(int adId) async {
    final res = await _dio.get<Map<String, dynamic>>('/ads/$adId/favorite-status');
    return res.data?['data']?['is_favorited'] as bool? ?? false;
  }

  Future<List<AdListModel>> fetchFavorites({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/favorites',
      queryParameters: {'page': page},
    );
    final data = res.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AdListModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(ref.watch(dioProvider));
});

final favoritesListProvider = FutureProvider<List<AdListModel>>((ref) {
  return ref.watch(favoriteRepositoryProvider).fetchFavorites();
});

final favoriteStatusProvider = FutureProvider.family<bool, int>((ref, adId) {
  return ref.watch(favoriteRepositoryProvider).checkStatus(adId);
});
