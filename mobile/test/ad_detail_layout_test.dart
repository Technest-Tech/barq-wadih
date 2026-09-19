import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/core/widgets/riyal_text.dart';
import 'package:barq_wadih/features/ads/data/ad_api.dart';
import 'package:barq_wadih/features/ads/domain/ad_model.dart';
import 'package:barq_wadih/features/ads/presentation/screens/ad_detail_screen.dart';
import 'package:barq_wadih/features/ads/presentation/widgets/ad_image_gallery.dart';

/// The ad page reads top to bottom as: what is for sale and its price, who is
/// selling it, where they are, the description, the "أخبرني" reminder, then the
/// photos and the way to contact the seller. The order lives in one Column that
/// several sessions edit, so pin it here.
void main() {
  const adId = 77;
  const title = 'ثلاجة للبيع';
  const description = 'ثلاجة بحالة ممتازة، استعمال سنة واحدة فقط.';
  const sellerName = 'محمد';
  const cityName = 'الرياض';

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
    'city': {'id': 1, 'name_ar': cityName},
    'category': {'id': 3, 'name_ar': 'أجهزة'},
    'user': {
      'id': 5,
      'name': sellerName,
      'is_verified': false,
      'is_dealer': false,
    },
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

  testWidgets('the page runs title → seller → city → description → photos', (
    tester,
  ) async {
    await pumpDetail(tester);

    double topOf(Finder finder) => tester.getTopLeft(finder).dy;

    final titleY = topOf(find.text(title));
    final priceY = topOf(find.byType(RiyalText).first);
    final sellerY = topOf(find.text(sellerName));
    final cityY = topOf(find.text(cityName));
    final descriptionY = topOf(find.text(description));
    final disclaimerY = topOf(find.textContaining('أخبرني أنك عن طريق'));
    final photosY = topOf(find.byType(AdImageGallery));
    final contactY = topOf(find.text('تواصل مع البائع'));

    expect(titleY, lessThan(priceY), reason: 'the item leads with its price');
    expect(priceY, lessThan(sellerY), reason: 'then who is selling it');
    expect(sellerY, lessThan(cityY), reason: 'then where they are');
    expect(cityY, lessThan(descriptionY), reason: 'then the description');
    expect(
      descriptionY,
      lessThan(disclaimerY),
      reason: 'the "أخبرني" reminder closes the written part',
    );
    expect(
      disclaimerY,
      lessThan(photosY),
      reason: 'the photos come after everything written',
    );
    expect(photosY, lessThan(contactY), reason: 'contact closes the page');
  });

  testWidgets('the view counter is not shown on the ad page', (tester) async {
    await pumpDetail(tester);

    expect(find.textContaining('مشاهدة'), findsNothing);
  });
}
