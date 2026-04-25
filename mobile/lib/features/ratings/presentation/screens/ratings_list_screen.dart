import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/rating_providers.dart';
import '../../domain/rating_model.dart';
import '../widgets/star_display.dart';
import '../widgets/rating_submit_sheet.dart';

class RatingsListScreen extends ConsumerWidget {
  const RatingsListScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.adId,
  });

  final int userId;
  final String userName;
  final int? adId; // if provided, show rate button

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(userRatingSummaryProvider(userId));
    final ratingsAsync = ref.watch(userRatingsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        title: Text(
          'تقييمات $userName',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (adId != null)
            TextButton(
              onPressed: () => _openRatingSheet(context, ref),
              child: const Text('قيّم', style: TextStyle(color: Color(0xFF818CF8))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          summaryAsync.when(
            loading: () => const _SummarySkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => _SummaryCard(summary: s),
          ),
          const SizedBox(height: 20),

          // Individual ratings
          ratingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (ratings) {
              if (ratings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.star_outline_rounded,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('لا توجد تقييمات بعد',
                            style: TextStyle(
                              fontSize: 15, color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: ratings.map((r) => _RatingCard(rating: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openRatingSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RatingSubmitSheet(adId: adId!, sellerName: userName),
    ).then((submitted) {
      if (submitted == true) {
        ref.invalidate(userRatingsProvider(userId));
        ref.invalidate(userRatingSummaryProvider(userId));
      }
    });
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Big avg number
          Column(
            children: [
              Text(
                summary.avgRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A1628),
                  height: 1,
                ),
              ),
              StarDisplay(value: summary.avgRating, showCount: false),
              const SizedBox(height: 4),
              Text(
                '${summary.ratingCount} تقييم',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Distribution bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final pct = summary.percentageFor(star);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8),
                      )),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${summary.distribution[star] ?? 0}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rating Card ───────────────────────────────────────────────────────────────

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});
  final RatingModel rating;

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatDate(rating.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rater + stars
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: rating.rater.avatar != null
                    ? NetworkImage(rating.rater.avatar!)
                    : null,
                backgroundColor: const Color(0xFF1B4FE4),
                child: rating.rater.avatar == null
                    ? Text(
                        rating.rater.name.isNotEmpty ? rating.rater.name[0] : '؟',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.rater.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF0A1628),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              StarDisplay(value: rating.stars.toDouble(), showCount: false, size: 14),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                rating.comment!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7)  return 'منذ ${diff.inDays} أيام';
    return DateFormat('d MMMM yyyy', 'ar').format(date);
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
