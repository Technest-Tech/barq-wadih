import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/banner_model.dart';
import 'banner_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final bannerRepositoryProvider = Provider<BannerRepository>((ref) {
  return BannerRepository(ref.watch(dioProvider));
});

// ── Banners by position ───────────────────────────────────────────────────────

final bannersProvider =
    FutureProvider.autoDispose.family<List<BannerModel>, String>((ref, position) {
  return ref.watch(bannerRepositoryProvider).fetchBanners(position);
});
