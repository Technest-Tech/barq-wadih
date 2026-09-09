import 'dart:async';
import 'dart:convert';

import 'package:barq_wadih/core/services/app_update_service.dart';
import 'package:barq_wadih/core/widgets/app_update_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 9, 5);
  var requests = 0;
  late Map<String, dynamic> listing;
  late Dio dio;
  AppUpdateService service() => AppUpdateService(
    dio: dio,
    now: () => now,
    installedInfo: () async => {
      'bundleId': 'com.barqwadih.app',
      'version': '1.0.2',
      'osVersion': '18.0',
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 5);
    requests = 0;
    listing = {
      'bundleId': 'com.barqwadih.app',
      'version': '1.0.3',
      'minimumOsVersion': '15.0',
      'trackViewUrl': 'https://apps.apple.com/sa/app/id6800784915',
    };
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(options.uri.host, 'itunes.apple.com');
            expect(options.queryParameters['country'], 'sa');
            expect(options.headers.containsKey('Authorization'), isFalse);
            handler.resolve(
              Response(
                requestOptions: options,
                data: jsonEncode({
                  'results': [listing],
                }),
              ),
            );
          },
        ),
      );
  });

  test(
    'compares numeric releases, ignoring build numbers and trailing zeros',
    () {
      expect(AppUpdateService.isNewerVersion('1.0.10', '1.0.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('2.0', '1.99.99'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.2', '1.0.2+14'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.0', '1'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.2', '1.0.3'), isFalse);
      expect(AppUpdateService.isNewerVersion('invalid', '1.0'), isFalse);
    },
  );

  test('finds published update and throttles repeated checks', () async {
    final checker = service();
    final update = await checker.check();
    expect(update?.version, '1.0.3');
    expect(update?.storeUrl.host, 'apps.apple.com');
    expect(await checker.check(), isNull);
    expect(requests, 1);
    now = now.add(const Duration(hours: 1));
    expect(await checker.check(), isNotNull);
  });

  test('snooze persists across launches and expires after one day', () async {
    await service().remindTomorrow();
    expect(await service().check(), isNull);
    expect(requests, 0);
    now = now.add(const Duration(days: 1));
    expect(await service().check(), isNotNull);
  });

  test('does not prompt for current, older or incompatible versions', () async {
    listing['version'] = '1.0.2';
    expect(await service().check(), isNull);
    listing['version'] = '1.0.1';
    expect(await service().check(), isNull);
    listing['version'] = '1.0.3';
    listing['minimumOsVersion'] = '19.0';
    expect(await service().check(), isNull);
  });

  test('rejects mismatched apps and non-Apple store URLs', () async {
    listing['bundleId'] = 'another.app';
    expect(await service().check(), isNull);
    listing['bundleId'] = 'com.barqwadih.app';
    listing['trackViewUrl'] = 'https://example.com/update';
    expect(await service().check(), isNull);
  });

  test(
    'handles offline, malformed and empty responses without interrupting app',
    () async {
      for (final body in ['invalid json', '{"results":[]}', '{}']) {
        dio.interceptors.clear();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(Response(requestOptions: options, data: body));
            },
          ),
        );
        expect(await service().check(), isNull);
      }
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          },
        ),
      );
      expect(await service().check(), isNull);
    },
  );

  Future<void> showUpdate(
    WidgetTester tester, {
    required String language,
    required Future<bool> Function(Uri) launch,
    double scale = 1,
    AppUpdate? update,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppUpdateDialog(
                  update:
                      update ??
                      AppUpdate(
                        '1.0.3',
                        Uri.parse('https://apps.apple.com/sa/app/id6800784915'),
                      ),
                  openStore: launch,
                ),
              ),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
  }

  for (final language in ['ar', 'en']) {
    testWidgets(
      '$language dialog fits narrow screen at 200% text and dismisses',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await showUpdate(
          tester,
          language: language,
          scale: 2,
          launch: (_) async => true,
        );
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(AlertDialog))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.tap(find.text(language == 'ar' ? 'لاحقًا' : 'Later'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  testWidgets('store opens once and closes dialog on success', (tester) async {
    final result = Completer<bool>();
    var launches = 0;
    await showUpdate(
      tester,
      language: 'ar',
      launch: (url) {
        launches++;
        expect(url.host, 'apps.apple.com');
        return result.future;
      },
    );
    await tester.tap(find.text('تحديث الآن'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    result.complete(true);
    await tester.pumpAndSettle();
    expect(launches, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('failed store launch offers retry and Later', (tester) async {
    await showUpdate(tester, language: 'en', launch: (_) async => false);
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open the store'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  test(
    'Android uses Play availability and build numbers, including same release name',
    () async {
      final info = <String, dynamic>{
        'platform': 'android',
        'bundleId': 'com.barqwadih.barq_wadih',
        'version': '1.0.3',
        'buildNumber': 15,
        'availableBuildNumber': 16,
        'updateAvailable': true,
      };
      AppUpdateService android() => AppUpdateService(
        dio: dio,
        installedInfo: () async => info,
        now: () => now,
      );
      final update = await android().check();
      expect(update?.storeUrl.host, 'play.google.com');
      expect(
        update?.storeUrl.queryParameters['id'],
        'com.barqwadih.barq_wadih',
      );
      expect(update?.version, isEmpty);
      expect(requests, 0, reason: 'Android must never query Apple');
      info['updateAvailable'] = false;
      expect(await android().check(), isNull);
      info['updateAvailable'] = true;
      info['availableBuildNumber'] = 15;
      expect(await android().check(), isNull);
      info['availableBuildNumber'] = 14;
      expect(await android().check(), isNull);
      info['availableBuildNumber'] = 16;
      info['bundleId'] = 'other.app';
      expect(await android().check(), isNull);
    },
  );

  test('Android unavailable Play service skips prompt safely', () async {
    final checker = AppUpdateService(installedInfo: () async => null);
    expect(await checker.check(), isNull);
  });

  testWidgets('Android prompt names Google Play and opens the correct listing', (
    tester,
  ) async {
    Uri? opened;
    await showUpdate(
      tester,
      language: 'en',
      update: AppUpdate(
        '',
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.barqwadih.barq_wadih',
        ),
      ),
      launch: (url) async {
        opened = url;
        return true;
      },
    );
    expect(find.textContaining('Google Play'), findsOneWidget);
    expect(find.textContaining('App Store'), findsNothing);
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(opened?.host, 'play.google.com');
    expect(find.byType(AlertDialog), findsNothing);
  });
}
