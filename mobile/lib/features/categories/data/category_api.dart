// lib/features/categories/data/category_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/category_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class CategoryRepository {
  final Dio _dio;

  static const _cacheKey = 'api_cache_categories_v1';

  const CategoryRepository(this._dio);

  static Future<void> _writeCache(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (_) {
      // Caching must never delay or fail a successful API response.
    }
  }

  static Future<List<dynamic>?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      return cached == null ? null : jsonDecode(cached) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the full hierarchical category tree from GET /categories.
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/categories');
      final data = response.data!['data'] as List<dynamic>;
      unawaited(_writeCache(data));
      return data
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .where((cat) => cat.slug != 'real-estate')
          .toList();
    } on DioException catch (e) {
      final cached = await _readCache();
      if (cached != null) {
        return cached
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .where((cat) => cat.slug != 'real-estate')
            .toList();
      }
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في تحميل الأقسام',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(dioProvider));
});

/// AsyncNotifier that fetches the full category tree once and caches it.
final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(
      CategoriesNotifier.new,
    );

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  Future<List<CategoryModel>> build() {
    return ref.read(categoryRepositoryProvider).getCategories();
  }

  /// Force-refresh from the API.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(categoryRepositoryProvider).getCategories(),
    );
  }
}
