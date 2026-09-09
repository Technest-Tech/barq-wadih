import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/features/ads/presentation/screens/post_ad_screen.dart';

/// The post-ad wizard is five PageView steps over one pile of state, and every
/// bug here was the same shape: the seller moved backwards and the wizard came
/// back holding something other than what they had left.
void main() {
  Map<String, dynamic> category(
    int id,
    String name, {
    List<Map<String, dynamic>> children = const [],
  }) => {
    'id': id,
    'name_ar': name,
    'name_en': 'cat$id',
    'slug': 'cat$id',
    'is_active': true,
    'children': children,
  };

  /// A tree with one leaf category and one parent the seller can drill into.
  final categoriesPayload = [
    category(1, 'أجهزة'),
    category(
      2,
      'سيارات',
      children: [category(21, 'تويوتا'), category(22, 'نيسان')],
    ),
  ];

  Dio fakeApi({List<String>? requests}) {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests?.add(options.path);
            final data = switch (options.path) {
              '/categories' => {'data': categoriesPayload},
              '/regions' => {'data': <dynamic>[]},
              _ when options.path.endsWith('/fields') => {'data': <dynamic>[]},
              _ => {'data': <dynamic>[]},
            };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
    return dio;
  }

  /// Mounts the wizard under a real GoRouter, so `context.pop()` behaves the
  /// way it does in the app and "did the wizard close?" is observable.
  /// Taps a widget after scrolling it into view — the pledge text alone is
  /// taller than a phone screen, so a blind tap lands on nothing.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// A parked draft, in the shape AdDraftStore writes.
  Map<String, Object> storedDraft({int step = 2}) => {
    'post_ad_draft_v1': jsonEncode({
      'version': 1,
      'saved_at': DateTime.now().toIso8601String(),
      'step': step,
      'pledge_accepted': true,
      'category': {
        'id': 1,
        'name_ar': 'أجهزة',
        'name_en': 'appliances',
        'slug': 'appliances',
      },
      'browsing_category_id': null,
      'title': 'ثلاجة محفوظة',
      'description': 'وصف محفوظ من قبل',
      'price': '2400',
      'phone': '',
      'price_option': 'fixed',
      'show_phone_publicly': false,
      'field_values': <String, String>{},
      'image_paths': <String>[],
      'region': null,
      'city': null,
      'district': null,
      'district_free_text': '',
      'latitude': null,
      'longitude': null,
    }),
  };

  Future<GoRouter> pumpWizard(
    WidgetTester tester,
    Dio dio, {
    Map<String, Object>? prefs,
  }) async {
    SharedPreferences.setMockInitialValues(prefs ?? {});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/post-ad',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/post-ad', builder: (_, __) => const PostAdScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Accept the pledge and land on the category step.
  Future<void> passPledge(WidgetTester tester) async {
    await tapVisible(tester, find.textContaining('أوافق على هذا التعهّد'));
    await tapVisible(tester, find.text('أوافق وأتابع'));
  }

  /// The Android back button / iOS edge swipe, as the framework delivers it.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('system back steps back through the wizard instead of closing it',
      (tester) async {
    final router = await pumpWizard(tester, fakeApi());
    await passPledge(tester);
    expect(find.text('اختر القسم'), findsOneWidget);

    // Used to pop the whole route and bin the draft.
    await systemBack(tester);
    expect(
      find.text('أوافق وأتابع'),
      findsOneWidget,
      reason: 'back must return to the pledge step, not close the wizard',
    );
    expect(router.routerDelegate.currentConfiguration.uri.path, '/post-ad');
  });

  testWidgets('back leaves a sub-category list before it leaves the step',
      (tester) async {
    await pumpWizard(tester, fakeApi());
    await passPledge(tester);

    await tapVisible(tester, find.text('سيارات'));
    expect(find.text('تويوتا'), findsOneWidget);

    await systemBack(tester);
    expect(
      find.text('أجهزة'),
      findsOneWidget,
      reason: 'back inside a sub-list returns to the parent list',
    );
    expect(find.text('أوافق وأتابع'), findsNothing);
  });

  testWidgets('returning to the category step lands on the same sub-list',
      (tester) async {
    await pumpWizard(tester, fakeApi());
    await passPledge(tester);

    await tapVisible(tester, find.text('سيارات'));
    await tapVisible(tester, find.text('تويوتا'));
    expect(find.text('معلومات الإعلان'), findsOneWidget);

    await systemBack(tester);
    // The sub-list used to be rebuilt from scratch, dumping the seller back at
    // the top level with no idea where they had been.
    expect(
      find.text('نيسان'),
      findsOneWidget,
      reason: 'the drilled-into sub-list must survive leaving the step',
    );
  });

  testWidgets('typed details survive a trip forward and back', (tester) async {
    await pumpWizard(tester, fakeApi());
    await passPledge(tester);
    await tapVisible(tester, find.text('أجهزة'));

    await tester.enterText(find.byType(TextField).first, 'ثلاجة ال جي');
    await tester.pumpAndSettle();

    await systemBack(tester); // to categories
    await tapVisible(tester, find.text('أجهزة'));

    expect(
      find.text('ثلاجة ال جي'),
      findsOneWidget,
      reason: 'the title the seller typed must still be there',
    );
  });

  testWidgets('leaving a half-written ad asks before discarding it',
      (tester) async {
    final router = await pumpWizard(tester, fakeApi());
    await passPledge(tester);
    await tapVisible(tester, find.text('أجهزة'));
    await tester.enterText(find.byType(TextField).first, 'ثلاجة');
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byIcon(Icons.close_rounded));

    expect(find.text('إلغاء الإعلان؟'), findsOneWidget);
    await tester.tap(find.text('متابعة التعبئة'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/post-ad',
      reason: 'declining the prompt keeps the seller in the wizard',
    );

    await tapVisible(tester, find.byIcon(Icons.close_rounded));
    await tester.tap(find.text('تجاهل'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });

  testWidgets('closing an untouched wizard does not nag', (tester) async {
    final router = await pumpWizard(tester, fakeApi());

    await tapVisible(tester, find.byIcon(Icons.close_rounded));

    expect(find.text('إلغاء الإعلان؟'), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });

  testWidgets('hammering Next does not desync the step indicator',
      (tester) async {
    await pumpWizard(tester, fakeApi());
    await passPledge(tester);
    await tapVisible(tester, find.text('أجهزة'));

    await tester.enterText(find.byType(TextField).at(0), 'ثلاجة ال جي');
    await tester.enterText(
      find.byType(TextField).at(1),
      'ثلاجة بحالة ممتازة للبيع',
    );
    await tester.enterText(find.byType(TextField).at(2), '1500');
    await tester.pumpAndSettle();

    // Two taps inside the 350ms page animation. `nextPage` read the live
    // fractional page, so the indicator advanced twice and the page once.
    final next = find.text('التالي: الصور');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(next, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('صور الإعلان'), findsOneWidget);

    await systemBack(tester);
    expect(
      find.text('معلومات الإعلان'),
      findsOneWidget,
      reason: 'one back from the images step lands on details, not past it',
    );
  });

  group('draft', () {
    testWidgets('an unfinished ad is offered back on the next visit',
        (tester) async {
      await pumpWizard(tester, fakeApi(), prefs: storedDraft());

      expect(find.text('لديك إعلان لم يكتمل'), findsOneWidget);
      await tester.tap(find.text('متابعة الإعلان'));
      await tester.pumpAndSettle();

      // Restored straight onto the step the seller left off at, with the text
      // they had written still in the fields.
      expect(find.text('معلومات الإعلان'), findsOneWidget);
      expect(find.text('ثلاجة محفوظة'), findsOneWidget);
      expect(find.text('وصف محفوظ من قبل'), findsOneWidget);
      expect(find.text('2400'), findsOneWidget);
    });

    testWidgets('declining the draft starts clean and does not ask again',
        (tester) async {
      await pumpWizard(tester, fakeApi(), prefs: storedDraft());

      await tester.tap(find.text('إعلان جديد'));
      await tester.pumpAndSettle();

      expect(find.text('ثلاجة محفوظة'), findsNothing);
      // A fresh ad starts at the pledge.
      expect(find.text('أوافق وأتابع'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('post_ad_draft_v1'),
        isNull,
        reason: 'a declined draft is thrown away, not offered again',
      );
    });

    testWidgets('nothing is offered when there is no draft', (tester) async {
      await pumpWizard(tester, fakeApi());
      expect(find.text('لديك إعلان لم يكتمل'), findsNothing);
    });

    testWidgets('writing an ad parks it on disk', (tester) async {
      await pumpWizard(tester, fakeApi());
      await passPledge(tester);
      await tapVisible(tester, find.text('أجهزة'));

      await tester.enterText(find.byType(TextField).first, 'غسالة أوتوماتيك');
      // The write is debounced, so let the timer fire.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('post_ad_draft_v1');
      expect(raw, isNotNull, reason: 'the half-written ad must be on disk');
      expect(jsonDecode(raw!)['title'], 'غسالة أوتوماتيك');
    });

    testWidgets('discarding the ad also clears the parked draft',
        (tester) async {
      await pumpWizard(tester, fakeApi(), prefs: storedDraft());
      await tester.tap(find.text('متابعة الإعلان'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byIcon(Icons.close_rounded));
      await tester.tap(find.text('تجاهل'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('post_ad_draft_v1'), isNull);
    });
  });
}
