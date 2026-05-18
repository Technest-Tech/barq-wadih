// lib/features/categories/data/category_api.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/category_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class CategoryRepository {
  final Dio _dio;

  const CategoryRepository(this._dio);

  /// Fetch the full hierarchical category tree from GET /categories.
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/categories');
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .where((cat) => cat.slug != 'real-estate')
          .toList();
    } on DioException catch (e) {
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
