// lib/features/regions/data/region_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/region_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class RegionRepository {
  final Dio _dio;

  const RegionRepository(this._dio);

  Future<void> _writeCache(String cacheKey, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
    } catch (_) {
      // Caching must never delay or fail a successful API response.
    }
  }

  Future<List<dynamic>?> _readCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      return cached == null ? null : jsonDecode(cached) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<T>> _getCachedList<T>(
    String path,
    String cacheKey,
    T Function(Map<String, dynamic>) fromJson,
    String fallbackMessage,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data!['data'] as List<dynamic>;
      unawaited(_writeCache(cacheKey, data));
      return data
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        return cached
            .map((item) => fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? fallbackMessage,
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<RegionModel>> getRegions() async {
    return _getCachedList(
      '/regions',
      'api_cache_regions_v1',
      RegionModel.fromJson,
      'فشل في تحميل المناطق',
    );
  }

  Future<List<CityModel>> getCities(String regionSlug) async {
    return _getCachedList(
      '/regions/$regionSlug/cities',
      'api_cache_region_cities_${regionSlug}_v1',
      CityModel.fromJson,
      'فشل في تحميل المدن',
    );
  }

  Future<List<CityModel>> getAllCities() async {
    return _getCachedList(
      '/cities',
      'api_cache_all_cities_v1',
      CityModel.fromJson,
      'فشل في تحميل جميع المدن',
    );
  }

  Future<List<DistrictModel>> getDistricts(int cityId) async {
    return _getCachedList(
      '/cities/$cityId/districts',
      'api_cache_city_districts_${cityId}_v1',
      DistrictModel.fromJson,
      'فشل في تحميل الأحياء',
    );
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

final citiesProvider = FutureProvider.family<List<CityModel>, String>((
  ref,
  regionSlug,
) {
  return ref.read(regionRepositoryProvider).getCities(regionSlug);
});

final allCitiesProvider = FutureProvider<List<CityModel>>((ref) {
  return ref.read(regionRepositoryProvider).getAllCities();
});

final districtsProvider = FutureProvider.family<List<DistrictModel>, int>((
  ref,
  cityId,
) {
  return ref.read(regionRepositoryProvider).getDistricts(cityId);
});
