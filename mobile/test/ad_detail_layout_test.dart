import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/features/ads/data/ad_api.dart';
import 'package:barq_wadih/features/ads/domain/ad_model.dart';
import 'package:barq_wadih/features/ads/presentation/screens/ad_detail_screen.dart';
import 'package:barq_wadih/features/ads/presentation/widgets/ad_image_gallery.dart';

/// The written details come before the photos on the ad page: a buyer reads
/// what is for sale and its description, then scrolls into the pictures. The
/// order lives in one Column that several sessions edit, so pin it here.
void main() {
  const adId = 77;
  const title = 'ثلاجة للبيع';
  const description = 'ثلاجة بحالة ممتازة، استعمال سنة واحدة فقط.';

  // The detail screen fires marketing tracking from initState over a platform
  // channel no host answers in tests.
  const trackingChannel = MethodChannel('com.barqwadih.app/marketing_tracking');

  AdDetailModel ad() => AdDetailModel.fromJson({
    'id': adId,
    'title': title,
    'description': description,
    'price': 1500,
    'is_negotiable': false,
    'is_free': false,
    'status': 'active',
    'status_label': 'نشط',
    'images': <dynamic>[],
    'images_count': 0,
    'field_values': <dynamic>[],
    'is_boosted': false,
    'created_at': '2026-09-01T10:00:00Z',
    'published_at': '2026-09-01T10:00:00Z',
    'views_count': 12,
    'city': {'id': 1, 'name_ar': 'الرياض'},
    'category': {'id': 3, 'name_ar': 'أجهزة'},
    'user': {'id': 5, 'name': 'محمد', 'is_verified': false, 'is_dealer': false},
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(trackingChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(trackingChannel, null));

    // Everything the page fetches (questions, favourites, related ads) answers
    // empty — this test is about layout order, not content.
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(requestOptions: options, data: {'data': <dynamic>[]}),
          ),
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          adDetailProvider(adId).overrideWith((ref) => ad()),
        ],
        child: const MaterialApp(home: AdDetailScreen(adId: adId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('title and description are rendered above the photos', (
    tester,
  ) async {
    await pumpDetail(tester);

    final titleY = tester.getTopLeft(find.text(title)).dy;
    final descriptionY = tester.getTopLeft(find.text(description)).dy;
    final photosY = tester.getTopLeft(find.byType(AdImageGallery)).dy;

    expect(titleY, lessThan(descriptionY), reason: 'title leads the page');
    expect(
      descriptionY,
      lessThan(photosY),
      reason: 'the description is read before the photos are reached',
    );
  });
}
