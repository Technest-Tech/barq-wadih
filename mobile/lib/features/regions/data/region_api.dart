// lib/features/regions/data/region_api.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/region_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class RegionRepository {
  final Dio _dio;

  const RegionRepository(this._dio);

  Future<List<RegionModel>> getRegions() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/regions');
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => RegionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل المناطق',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<CityModel>> getCities(String regionSlug) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/regions/$regionSlug/cities',
      );
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل المدن',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<CityModel>> getAllCities() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/cities');
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل جميع المدن',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<DistrictModel>> getDistricts(int cityId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/cities/$cityId/districts');
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => DistrictModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في تحميل الأحياء',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final regionRepositoryProvider = Provider<RegionRepository>((ref) {
  return RegionRepository(ref.watch(dioProvider));
});

final regionsProvider =
    AsyncNotifierProvider<RegionsNotifier, List<RegionModel>>(
  RegionsNotifier.new,
);

class RegionsNotifier extends AsyncNotifier<List<RegionModel>> {
  @override
  Future<List<RegionModel>> build() {
    return ref.read(regionRepositoryProvider).getRegions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(regionRepositoryProvider).getRegions(),
    );
  }
}

final citiesProvider = FutureProvider.family<List<CityModel>, String>((ref, regionSlug) {
  return ref.read(regionRepositoryProvider).getCities(regionSlug);
});

final allCitiesProvider = FutureProvider<List<CityModel>>((ref) {
  return ref.read(regionRepositoryProvider).getAllCities();
});

final districtsProvider = FutureProvider.family<List<DistrictModel>, int>((ref, cityId) {
  return ref.read(regionRepositoryProvider).getDistricts(cityId);
});
