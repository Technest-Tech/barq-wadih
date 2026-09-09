import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barq_wadih/core/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> info;
  late Map<String, dynamic> policies;
  late DateTime now;
  late Dio dio;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 10);
    info = {
      'bundleId': 'com.barqwadih.app',
      'version': '1.0.3',
      'osVersion': '18.0',
    };
    policies = {
      'ios': {
        'bundle_id': 'com.barqwadih.app',
        'version': '1.0.4',
        'minimum_os': '15.0',
      },
    };
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(requestOptions: options, data: {'results': []}),
            );
          },
        ),
      );
  });
  AppUpdateService service() => AppUpdateService(
    dio: dio,
    installedInfo: () async => info,
    releasePolicy: () async => policies,
    now: () => now,
  );

  test('published iOS policy prompts for newer compatible version', () async {
    expect((await service().check())?.version, '1.0.4');
    info['version'] = '1.0.4';
    expect(await service().check(), isNull);
    info['version'] = '1.0.5';
    expect(await service().check(), isNull);
    info['version'] = '1.0.3';
    info['osVersion'] = '14.0';
    expect(await service().check(), isNull);
  });

  test('Later persists only for that release, never the next update', () async {
    final update = (await service().check())!;
    await service().remindTomorrow(update);
    expect(await service().check(), isNull);
    (policies['ios'] as Map)['version'] = '1.0.5';
    expect((await service().check())?.version, '1.0.5');
  });

  test('old global snooze cannot hide a new release', () async {
    SharedPreferences.setMockInitialValues({
      'app_update.remind_after': now
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
    });
    expect(await service().check(), isNotNull);
  });

  test(
    'newer Apple release bypasses a stale server policy and its snooze',
    () async {
      await service().remindTomorrow(
        AppUpdate(
          '1.0.4',
          Uri.parse('https://apps.apple.com/app/id6800784915'),
        ),
      );
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'results': [
                    {
                      'bundleId': 'com.barqwadih.app',
                      'trackId': 6800784915,
                      'version': '1.0.5',
                      'minimumOsVersion': '15.0',
                      'trackViewUrl': 'https://apps.apple.com/app/id6800784915',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      expect((await service().check())?.version, '1.0.5');
    },
  );

  test('server URLs are never used as arbitrary navigation targets', () async {
    (policies['ios'] as Map)['store_url'] = 'https://example.com/fake';
    expect(
      (await service().check())?.storeUrl.toString(),
      'https://apps.apple.com/app/id6800784915',
    );
  });

  test(
    'Android respects Play eligibility and uses server only on store-installed failures',
    () async {
      info = {
        'platform': 'android',
        'bundleId': 'com.barqwadih.barq_wadih',
        'version': '1.0.3',
        'buildNumber': 15,
        'sdkVersion': 33,
        'storeInstalled': true,
        'playAvailabilityKnown': false,
      };
      policies = {
        'android': {
          'bundle_id': 'com.barqwadih.barq_wadih',
          'version': '1.0.4',
          'build': 16,
          'minimum_sdk': 24,
        },
      };
      expect((await service().check())?.version, '1.0.4');
      info['storeInstalled'] = false;
      expect(await service().check(), isNull);
      info['storeInstalled'] = true;
      info['sdkVersion'] = 23;
      expect(await service().check(), isNull);
      info['sdkVersion'] = 33;
      info['playAvailabilityKnown'] = true;
      info['updateAvailable'] = false;
      expect(await service().check(), isNull);
      info['updateAvailable'] = true;
      info['availableBuildNumber'] = 16;
      expect((await service().check())?.version, '1.0.4');
      info['availableBuildNumber'] = 17;
      expect((await service().check())?.version, '');
    },
  );

  test('backend failure falls back to Apple lookup', () async {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.host, 'itunes.apple.com');
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'results': [
                  {
                    'bundleId': 'com.barqwadih.app',
                    'trackId': 6800784915,
                    'version': '1.0.4',
                    'minimumOsVersion': '15.0',
                    'trackViewUrl': 'https://apps.apple.com/app/id6800784915',
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final checker = AppUpdateService(
      dio: dio,
      installedInfo: () async => info,
      releasePolicy: () async => throw StateError('offline'),
    );
    expect((await checker.check())?.version, '1.0.4');
  });

  test('overlapping foreground checks produce one update result', () async {
    final pending = Completer<Map<String, dynamic>?>();
    final checker = AppUpdateService(
      dio: dio,
      installedInfo: () => pending.future,
      releasePolicy: () async => policies,
    );
    final first = checker.check();
    expect(await checker.check(), isNull);
    pending.complete(info);
    expect(await first, isNotNull);
  });
}
