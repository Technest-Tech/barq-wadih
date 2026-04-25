import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class FollowRepository {
  final Dio _dio;
  FollowRepository(this._dio);

  /// Toggle category follow. Returns new is_following state.
  Future<bool> toggleFollow(int categoryId, {int? cityId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/categories/$categoryId/follow',
      data: cityId != null ? {'city_id': cityId} : null,
    );
    return res.data?['data']?['is_following'] as bool? ?? false;
  }

  /// Check if user follows a category.
  Future<bool> checkStatus(int categoryId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/categories/$categoryId/follow-status',
    );
    return res.data?['data']?['is_following'] as bool? ?? false;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.watch(dioProvider));
});

final followStatusProvider = FutureProvider.family<bool, int>((ref, categoryId) {
  return ref.watch(followRepositoryProvider).checkStatus(categoryId);
});
