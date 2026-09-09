import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/features/ads/presentation/screens/ad_feed_screen.dart';

/// The feed list lives in [NestedScrollView.body], whose scroll position is NOT
/// the one the screen's own ScrollController tracks. Paging used to hang off
/// that controller, so it fired while the categories header collapsed and then
/// went silent — the feed stopped at page 1 no matter how far you scrolled.
void main() {
  const perPage = 20;
  const lastPage = 4;

  Map<String, dynamic> ad(int id) => {
    'id': id,
    'title': 'إعلان رقم $id',
    'price': 1000 + id,
    'is_negotiable': false,
    'is_free': false,
    'status': 'active',
    'status_label': 'نشط',
    'images_count': 0,
    'is_boosted': false,
    'created_at': '2026-09-01T10:00:00Z',
    'published_at': '2026-09-01T10:00:00Z',
  };

  /// Records every page the feed asks for and serves a 4-page ad list.
  (Dio, List<int>) fakeApi() {
    final requestedPages = <int>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = switch (options.path) {
              '/ads' => () {
                final page =
                    int.tryParse('${options.queryParameters['page'] ?? 1}') ??
                    1;
                requestedPages.add(page);
                return {
                  'data': [
                    for (var i = 0; i < perPage; i++)
                      ad((page - 1) * perPage + i + 1),
                  ],
                  'meta': {
                    'current_page': page,
                    'last_page': lastPage,
                    'per_page': perPage,
                    'total': perPage * lastPage,
                  },
                };
              }(),
              _ => {'data': <dynamic>[]},
            };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
    return (dio, requestedPages);
  }

  Future<void> pumpFeed(WidgetTester tester, Dio dio) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: AdFeedScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drag the ad list to its end repeatedly, letting each new page settle, the
  /// way a user thumbing through the feed does.
  Future<void> scrollToEnd(WidgetTester tester, {int gestures = 10}) async {
    for (var i = 0; i < gestures; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the feed keeps paging all the way to the last page', (
    tester,
  ) async {
    final (dio, requestedPages) = fakeApi();
    await pumpFeed(tester, dio);

    expect(requestedPages, [1], reason: 'first page loads on open');
    expect(find.text('إعلان رقم 1'), findsOneWidget);

    await scrollToEnd(tester);

    // Paging used to die after the categories header finished collapsing,
    // stranding the feed on page 2 however far you scrolled.
    expect(
      requestedPages,
      [1, 2, 3, 4],
      reason: 'every page must load as the user scrolls, then stop at the last',
    );
  });

  testWidgets('rapid scrolling requests each page once, in order', (
    tester,
  ) async {
    final (dio, requestedPages) = fakeApi();
    await pumpFeed(tester, dio);

    // Fling without settling between gestures, so scroll callbacks pile up
    // while a page request is still in flight.
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await scrollToEnd(tester);

    expect(
      requestedPages,
      [1, 2, 3, 4],
      reason:
          'no page requested twice and none skipped under concurrent scroll',
    );
  });
}
