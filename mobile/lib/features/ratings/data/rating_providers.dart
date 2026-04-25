import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../domain/rating_model.dart';
import 'rating_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(ref.watch(dioProvider));
});

// ── Ad ratings ────────────────────────────────────────────────────────────────

final adRatingsProvider = FutureProvider.family<List<RatingModel>, int>((ref, adId) {
  return ref.watch(ratingRepositoryProvider).fetchAdRatings(adId);
});

// ── User ratings ──────────────────────────────────────────────────────────────

final userRatingsProvider = FutureProvider.family<List<RatingModel>, int>((ref, userId) {
  return ref.watch(ratingRepositoryProvider).fetchUserRatings(userId);
});

// ── Rating summary ────────────────────────────────────────────────────────────

final userRatingSummaryProvider = FutureProvider.family<RatingSummary, int>((ref, userId) {
  return ref.watch(ratingRepositoryProvider).fetchUserRatingSummary(userId);
});
