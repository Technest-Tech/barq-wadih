import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barq_wadih/app.dart';
import 'package:barq_wadih/core/network/api_client.dart';

void main() {
  // Building the whole app runs the startup update check. Its guard admits
  // Android, and defaultTargetPlatform is android under flutter test, so it
  // reaches the real com.barqwadih.app/app_update channel — which no host
  // answers here, leaving the service's 10s timeout Timer pending when the
  // tree is torn down. AppUpdateService takes installedInfo as a constructor
  // parameter, so app_update_test.dart never hits this; only a full-app pump
  // does. Answering the channel with null completes the call, the timeout is
  // cancelled, and check() returns early.
  const updateChannel = MethodChannel('com.barqwadih.app/app_update');

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(updateChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(updateChannel, null));
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = switch (options.path) {
              '/ads' => {
                'data': <dynamic>[],
                'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
              },
              _ => {'data': <dynamic>[]},
            };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const BarqWadihApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
