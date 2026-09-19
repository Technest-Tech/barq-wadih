import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/features/ads/presentation/screens/my_ads_screen.dart';

/// "تحديث" bumps an ad to the top of the feed once every 24 hours. The backend
/// owns that window and ships it as `next_refresh_at`; My Ads has to honour it
/// instead of firing a request that comes back 422.
void main() {
  const adId = 42;

  Map<String, dynamic> adJson({String? nextRefreshAt}) => {
    'id': adId,
    'title': 'ثلاجة للبيع',
    'price': 1500,
    'is_negotiable': false,
    'is_free': false,
    'status': 'active',
    'status_label': 'نشط',
    'images_count': 0,
    'is_boosted': false,
    'created_at': '2026-09-01T10:00:00Z',
    'published_at': '2026-09-01T10:00:00Z',
    'expires_at': '2026-12-01T10:00:00Z',
    'can_renew': false,
    'can_refresh': nextRefreshAt == null,
    'next_refresh_at': nextRefreshAt,
    'city': {'id': 1, 'name_ar': 'الرياض'},
    'category': {'id': 3, 'name_ar': 'أجهزة'},
  };

  /// Pumps My Ads holding a single ad, and hands back the paths of every
  /// request the screen sent so the test can see whether a bump went out.
  Future<List<String>> pumpMyAds(
    WidgetTester tester, {
    String? nextRefreshAt,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final posted = <String>[];

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') posted.add(options.path);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': options.path == '/ads/mine'
                      ? [adJson(nextRefreshAt: nextRefreshAt)]
                      : adJson(nextRefreshAt: nextRefreshAt),
                },
              ),
            );
          },
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: MyAdsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    return posted;
  }

  testWidgets('an ad inside its 24h window does not send a bump', (
    tester,
  ) async {
    final posted = await pumpMyAds(
      tester,
      nextRefreshAt: DateTime.now()
          .add(const Duration(hours: 5, minutes: 30))
          .toUtc()
          .toIso8601String(),
    );

    await tester.tap(find.text('تحديث'));
    await tester.pumpAndSettle();

    expect(posted, isEmpty, reason: 'the locked button never reaches the API');
    // ...and it says why, with the wait spelled out.
    expect(find.textContaining('متبقي 5 ساعة'), findsOneWidget);
  });

  testWidgets('an ad past its 24h window bumps straight away', (tester) async {
    final posted = await pumpMyAds(tester);

    await tester.tap(find.text('تحديث'));
    await tester.pumpAndSettle();

    expect(posted, contains('/ads/$adId/refresh'));
  });

  testWidgets('a wait under an hour is shown in minutes', (tester) async {
    await pumpMyAds(
      tester,
      nextRefreshAt: DateTime.now()
          .add(const Duration(minutes: 12))
          .toUtc()
          .toIso8601String(),
    );

    await tester.tap(find.text('تحديث'));
    await tester.pumpAndSettle();

    expect(find.textContaining('متبقي 12 دقيقة'), findsOneWidget);
  });
}
