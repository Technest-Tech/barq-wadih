import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barq_wadih/app.dart';
import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/core/services/app_update_service.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final backgrounded in [false, true]) {
      testWidgets(
        '$platform shows startup popup, backgrounded=$backgrounded',
        (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          SharedPreferences.setMockInitialValues({});
          final ready = Completer<Map<String, dynamic>?>();
          final checker = AppUpdateService(
            dio: Dio()
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (options, handler) {
                    handler.resolve(
                      Response(requestOptions: options, data: {'results': []}),
                    );
                  },
                ),
              ),
            installedInfo: () => ready.future,
            releasePolicy: () async => {
              'ios': {
                'bundle_id': 'com.barqwadih.app',
                'version': '1.0.4',
                'minimum_os': '15',
              },
              'android': {
                'bundle_id': 'com.barqwadih.barq_wadih',
                'version': '1.0.4',
                'build': 16,
                'minimum_sdk': 24,
              },
            },
          );
          final dio = Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'data': <dynamic>[],
                        'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
                      },
                    ),
                  );
                },
              ),
            );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dioProvider.overrideWithValue(dio),
                appUpdateServiceProvider.overrideWithValue(checker),
              ],
              child: const BarqWadihApp(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          if (backgrounded) {
            for (final state in [
              AppLifecycleState.inactive,
              AppLifecycleState.hidden,
              AppLifecycleState.paused,
            ]) {
              tester.binding.handleAppLifecycleStateChanged(state);
            }
          }
          ready.complete(
            platform == TargetPlatform.iOS
                ? {
                    'bundleId': 'com.barqwadih.app',
                    'version': '1.0.3',
                    'osVersion': '18.0',
                  }
                : {
                    'platform': 'android',
                    'bundleId': 'com.barqwadih.barq_wadih',
                    'version': '1.0.3',
                    'buildNumber': 15,
                    'sdkVersion': 33,
                    'storeInstalled': true,
                    'playAvailabilityKnown': false,
                  },
          );
          await tester.pumpAndSettle();
          if (backgrounded) {
            expect(find.byType(AlertDialog), findsNothing);
            for (final state in [
              AppLifecycleState.hidden,
              AppLifecycleState.inactive,
              AppLifecycleState.resumed,
            ]) {
              tester.binding.handleAppLifecycleStateChanged(state);
            }
            await tester.pumpAndSettle();
          }
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.textContaining('1.0.4'), findsOneWidget);
          await tester.tap(find.byType(TextButton).last);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
