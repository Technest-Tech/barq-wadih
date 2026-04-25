import 'package:dio/dio.dart';

import '../domain/banner_model.dart';

class BannerRepository {
  final Dio _dio;
  BannerRepository(this._dio);

  /// Fetch active banners for a given position.
  Future<List<BannerModel>> fetchBanners(String position) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/banners',
      queryParameters: {'position': position},
    );
    final data = res.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Track a banner click and return the redirect URL (if any).
  Future<String?> trackClick(int bannerId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/banners/$bannerId/click',
    );
    return res.data?['data']?['redirect_url'] as String?;
  }
}
