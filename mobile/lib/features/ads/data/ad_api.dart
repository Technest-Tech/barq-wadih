// lib/features/ads/data/ad_api.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/ad_model.dart';

// ── Commission preview model ──────────────────────────────────────────────────

class CommissionPreviewModel {
  final double commissionAmount;
  final String? commissionRate; // null for flat-fee categories
  final double? minimumCommission;
  final String note;
  final bool isFlatFee;

  const CommissionPreviewModel({
    required this.commissionAmount,
    required this.commissionRate,
    required this.minimumCommission,
    required this.note,
    required this.isFlatFee,
  });

  factory CommissionPreviewModel.fromJson(Map<String, dynamic> json) {
    return CommissionPreviewModel(
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      commissionRate: json['commission_rate'] as String?,
      minimumCommission: json['minimum_commission'] != null
          ? (json['minimum_commission'] as num).toDouble()
          : null,
      note: json['note'] as String? ?? '',
      isFlatFee: json['is_flat_fee'] as bool? ?? false,
    );
  }
}

/// Key type for the commission preview provider.
typedef CommissionPreviewKey = ({
  double price,
  int categoryId,
  String sellerType,
});

class AdsFilter {
  final int? categoryId;
  final List<int>? categoryIds;
  final int? cityId;
  final List<int>? cityIds;
  final int? regionId;
  final double? priceMin;
  final double? priceMax;
  final String? q;
  final String sort;
  final int page;
  final String? condition; // 'new' | 'used' | null (all)
  final bool? withImages; // true = only ads with images
  final bool? negotiable; // true = only negotiable ads

  const AdsFilter({
    this.categoryId,
    this.categoryIds,
    this.cityId,
    this.cityIds,
    this.regionId,
    this.priceMin,
    this.priceMax,
    this.q,
    this.sort = 'newest',
    this.page = 1,
    this.condition,
    this.withImages,
    this.negotiable,
  });

  AdsFilter copyWith({
    int? categoryId,
    List<int>? categoryIds,
    int? cityId,
    List<int>? cityIds,
    int? regionId,
    double? priceMin,
    double? priceMax,
    String? q,
    String? sort,
    int? page,
    String? condition,
    bool? withImages,
    bool? negotiable,
    bool clearCategory = false,
    bool clearCategoryIds = false,
    bool clearCity = false,
    bool clearCityIds = false,
    bool clearRegion = false,
    bool clearCondition = false,
  }) {
    return AdsFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryIds: clearCategoryIds ? null : (categoryIds ?? this.categoryIds),
      cityId: clearCity ? null : (cityId ?? this.cityId),
      cityIds: clearCityIds ? null : (cityIds ?? this.cityIds),
      regionId: clearRegion ? null : (regionId ?? this.regionId),
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      q: q ?? this.q,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      condition: clearCondition ? null : (condition ?? this.condition),
      withImages: withImages ?? this.withImages,
      negotiable: negotiable ?? this.negotiable,
    );
  }

  Map<String, dynamic> toQueryParams() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      if (categoryIds != null && categoryIds!.isNotEmpty)
        'category_ids': categoryIds!.join(','),
      if (cityId != null) 'city_id': cityId,
      if (cityIds != null && cityIds!.isNotEmpty)
        'city_ids': cityIds!.join(','),
      if (regionId != null) 'region_id': regionId,
      if (priceMin != null) 'price_min': priceMin,
      if (priceMax != null) 'price_max': priceMax,
      if (q != null && q!.isNotEmpty) 'q': q,
      if (condition != null) 'condition': condition,
      if (withImages == true) 'with_images': 1,
      if (negotiable == true) 'negotiable': 1,
      'sort': sort,
      'page': page,
    };
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class AdRepository {
  final Dio _dio;

  const AdRepository(this._dio);

  /// GET /ads — paginated ad feed
  Future<({List<AdListModel> ads, bool hasMore, int total})> getAds(
    AdsFilter filter,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ads',
        queryParameters: filter.toQueryParams(),
      );
      final body = response.data!;
      final dataList = body['data'] as List<dynamic>;
      final meta = body['meta'] as Map<String, dynamic>?;
      final ads = dataList
          .map((e) => AdListModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = meta != null
          ? (meta['current_page'] as int? ?? 1) <
                (meta['last_page'] as int? ?? 1)
          : false;
      final total = meta?['total'] as int? ?? ads.length;
      return (ads: ads, hasMore: hasMore, total: total);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في تحميل الإعلانات',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /ads/{id} — single ad detail
  Future<AdDetailModel> getAd(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/ads/$id');
      final data = response.data!['data'] as Map<String, dynamic>;
      return AdDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في تحميل الإعلان',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /ads/mine — current user's ads
  Future<List<AdListModel>> getMyAds() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/ads/mine');
      final body = response.data!;
      final dataList = body['data'] as List<dynamic>;
      return dataList
          .map((e) => AdListModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في تحميل إعلاناتك',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// POST /ads — create new ad (multipart)
  Future<AdDetailModel> createAd(FormData formData) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ads',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final wrapper = response.data!['data'] as Map<String, dynamic>;
      final data = (wrapper['ad'] as Map<String, dynamic>?) ?? wrapper;
      return AdDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في نشر الإعلان',
        statusCode: e.response?.statusCode,
        errors: e.response?.data?['errors'] as Map<String, dynamic>?,
      );
    }
  }

  /// POST /ads/{id}/payment/proof — upload a bank-transfer receipt (multipart).
  /// Moves the ad's publish-fee payment into `under_review` for admin approval.
  Future<AdDetailModel> uploadPaymentProof(int id, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'proof': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/ads/$id/payment/proof',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return AdDetailModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل رفع إيصال التحويل',
        statusCode: e.response?.statusCode,
        errors: e.response?.data?['errors'] as Map<String, dynamic>?,
      );
    }
  }

  /// DELETE /ads/{id}
  Future<void> deleteAd(int id) async {
    try {
      await _dio.delete<void>('/ads/$id');
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في حذف الإعلان',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /search — Meilisearch-powered full-text search with fallback
  Future<({List<AdListModel> ads, bool hasMore, int total})> searchAds(
    AdsFilter filter,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search',
        queryParameters: filter.toQueryParams(),
      );
      final body = response.data!;
      final dataList = body['data'] as List<dynamic>;
      final meta = body['meta'] as Map<String, dynamic>?;
      final ads = dataList
          .map((e) => AdListModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = meta != null
          ? (meta['current_page'] as int? ?? 1) <
                (meta['last_page'] as int? ?? 1)
          : false;
      final total = meta?['total'] as int? ?? ads.length;
      return (ads: ads, hasMore: hasMore, total: total);
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data?['message'] as String? ?? 'فشل في البحث',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /search/suggestions — autocomplete completions
  Future<List<String>> getSearchSuggestions(String q) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search/suggestions',
        queryParameters: {'q': q},
      );
      final data = response.data!['data'] as List<dynamic>;
      return data.cast<String>();
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ??
            'فشل في تحميل الاقتراحات',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /search/popular — top N most-viewed active ads
  Future<List<AdListModel>> getPopularAds({
    int limit = 3,
    int? categoryId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/search/popular',
        queryParameters: {
          'limit': limit,
          if (categoryId != null) 'category_id': categoryId,
        },
      );
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => AdListModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ??
            'فشل في تحميل الإعلانات الشائعة',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// PATCH /ads/{id} — update existing ad (multipart)
  Future<AdDetailModel> updateAd(int id, FormData formData) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/ads/$id',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return AdDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في تحديث الإعلان',
        statusCode: e.response?.statusCode,
        errors: e.response?.data?['errors'] as Map<String, dynamic>?,
      );
    }
  }

  /// GET /ads/commission-preview — calculate commission before posting
  Future<CommissionPreviewModel> commissionPreview(
    double price, {
    int categoryId = 0,
    String sellerType = 'individual',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ads/commission-preview',
        queryParameters: {
          'price': price,
          'category_id': categoryId,
          'seller_type': sellerType,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return CommissionPreviewModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في حساب العمولة',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// POST /ads/{id}/sold
  Future<AdListModel> markSold(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/ads/$id/sold');
      final data = response.data!['data'] as Map<String, dynamic>;
      return AdListModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ??
            'فشل في تحديد الإعلان كمُباع',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// POST /ads/{id}/boost — Premium boost
  Future<AdDetailModel> boostAd(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/ads/$id/boost');
      final data = response.data!['data'] as Map<String, dynamic>;
      return AdDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في ترقية الإعلان',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// POST /ads/{id}/refresh — Refresh ad
  Future<AdDetailModel> refreshAd(int id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ads/$id/refresh',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return AdDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ?? 'فشل في تحديث الإعلان',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /boost-config — Boost pricing & rules
  Future<Map<String, dynamic>> getBoostConfig() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/boost-config');
      return response.data!['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ??
            'فشل في تحميل إعدادات الترقية',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// GET /categories/{id}/fields
  Future<List<CategoryFieldModel>> getCategoryFields(int categoryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/categories/$categoryId/fields',
      );
      final data = response.data!['data'] as List<dynamic>;
      return data
          .map((e) => CategoryFieldModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message:
            e.response?.data?['message'] as String? ??
            'فشل في تحميل حقول التصنيف',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final adRepositoryProvider = Provider<AdRepository>((ref) {
  return AdRepository(ref.watch(dioProvider));
});

/// Feed provider — supports filters + pagination
final adsFeedProvider =
    AsyncNotifierProvider<
      AdsFeedNotifier,
      ({List<AdListModel> ads, bool hasMore, int total})
    >(AdsFeedNotifier.new);

class AdsFeedNotifier
    extends AsyncNotifier<({List<AdListModel> ads, bool hasMore, int total})> {
  AdsFilter _filter = const AdsFilter();
  int _requestId = 0;

  @override
  Future<({List<AdListModel> ads, bool hasMore, int total})> build() {
    return ref.read(adRepositoryProvider).getAds(_filter);
  }

  void applyFilter(AdsFilter filter) {
    _filter = filter.copyWith(page: 1);
    state = const AsyncLoading();
    final id = ++_requestId;
    ref
        .read(adRepositoryProvider)
        .getAds(_filter)
        .then((result) {
          if (id == _requestId) state = AsyncData(result);
        })
        .catchError((Object e) {
          if (id == _requestId) state = AsyncError(e, StackTrace.current);
        });
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    _filter = _filter.copyWith(page: _filter.page + 1);
    final more = await ref.read(adRepositoryProvider).getAds(_filter);
    state = AsyncData((
      ads: [...current.ads, ...more.ads],
      hasMore: more.hasMore,
      total: more.total,
    ));
  }

  Future<void> refresh() async {
    _filter = _filter.copyWith(page: 1);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adRepositoryProvider).getAds(_filter),
    );
  }
}

/// Ad detail — FutureProvider.family
final adDetailProvider = FutureProvider.family<AdDetailModel, int>((ref, id) {
  return ref.read(adRepositoryProvider).getAd(id);
});

/// My ads
final myAdsProvider = AsyncNotifierProvider<MyAdsNotifier, List<AdListModel>>(
  MyAdsNotifier.new,
);

class MyAdsNotifier extends AsyncNotifier<List<AdListModel>> {
  @override
  Future<List<AdListModel>> build() {
    return ref.read(adRepositoryProvider).getMyAds();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(adRepositoryProvider).getMyAds(),
    );
  }

  void removeLocally(int id) {
    final current = state.value ?? [];
    state = AsyncData(current.where((a) => a.id != id).toList());
  }

  void updateStatus(int id, String newStatus, String newLabel) {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((a) {
        if (a.id != id) return a;
        return AdListModel.fromJson({
          'id': a.id,
          'title': a.title,
          'price': a.price?.toString(),
          'is_negotiable': a.isNegotiable,
          'is_free': a.isFree,
          'status': newStatus,
          'status_label': newLabel,
          'primary_image': a.primaryImage != null
              ? {
                  'id': a.primaryImage!.id,
                  'image_url': a.primaryImage!.imageUrl,
                  'thumbnail_url': a.primaryImage!.thumbnailUrl,
                  'sort_order': a.primaryImage!.sortOrder,
                }
              : null,
          'category': a.category != null
              ? {
                  'id': a.category!.id,
                  'name_ar': a.category!.nameAr,
                  'icon': a.category!.icon,
                }
              : null,
          'city': a.city != null
              ? {'id': a.city!.id, 'name_ar': a.city!.nameAr}
              : null,
          'region': a.region != null
              ? {'id': a.region!.id, 'name_ar': a.region!.nameAr}
              : null,
          'is_boosted': a.isBoosted,
          'boosted_until': a.boostedUntil?.toIso8601String(),
          'published_at': a.publishedAt?.toIso8601String(),
          'created_at': a.createdAt.toIso8601String(),
        });
      }).toList(),
    );
  }
}

/// Category fields — FutureProvider.family
final categoryFieldsProvider =
    FutureProvider.family<List<CategoryFieldModel>, int>((ref, categoryId) {
      return ref.read(adRepositoryProvider).getCategoryFields(categoryId);
    });

/// Commission preview — FutureProvider.family keyed by (price, categoryId, sellerType)
final commissionPreviewProvider =
    FutureProvider.family<CommissionPreviewModel, CommissionPreviewKey>((
      ref,
      key,
    ) {
      return ref
          .read(adRepositoryProvider)
          .commissionPreview(
            key.price,
            categoryId: key.categoryId,
            sellerType: key.sellerType,
          );
    });

/// Dedicated search — FutureProvider.family keyed by filter
final searchProvider =
    FutureProvider.family<
      ({List<AdListModel> ads, bool hasMore, int total}),
      AdsFilter
    >((ref, filter) {
      return ref.read(adRepositoryProvider).searchAds(filter);
    });

/// Popular ads — FutureProvider.family keyed by (limit, categoryId)
typedef PopularAdsKey = ({int limit, int? categoryId});

final popularAdsProvider =
    FutureProvider.family<List<AdListModel>, PopularAdsKey>((ref, key) {
      return ref
          .read(adRepositoryProvider)
          .getPopularAds(limit: key.limit, categoryId: key.categoryId);
    });

/// Navigation bridge: categories screen writes here, feed screen reads & clears.
/// Holds (categoryId, subcategoryId) — subcategoryId is the leaf to filter by.
typedef CategoryNav = ({int categoryId, int? subcategoryId});

final categoryNavProvider = NotifierProvider<CategoryNavNotifier, CategoryNav?>(
  CategoryNavNotifier.new,
);

class CategoryNavNotifier extends Notifier<CategoryNav?> {
  @override
  CategoryNav? build() => null;

  void set(CategoryNav nav) => state = nav;
  void clear() => state = null;
}
