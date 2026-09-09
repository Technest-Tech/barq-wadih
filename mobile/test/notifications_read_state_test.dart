import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/features/notifications/presentation/screens/notifications_screen.dart';

/// A notification stayed unread until you tapped its individual row, so the
/// bell badge survived a trip through the notification centre — the user had
/// read everything and the app still insisted otherwise.
void main() {
  Map<String, dynamic> notif(int id, {required bool isRead, String? convId}) => {
    'id': id,
    'type': convId != null ? 'new_message' : 'sale_fee',
    'title': 'إشعار $id',
    'body': 'نص الإشعار',
    'data': convId != null
        ? {'type': 'chat', 'conversation_id': convId}
        : {'type': 'sale_fee', 'ad_id': 5},
    'is_read': isRead,
    'read_at': null,
    'created_at': '2026-09-01T10:00:00Z',
  };

  /// Serves two unread notifications and records every path the screen posts to.
  (Dio, List<String>) fakeApi({required List<Map<String, dynamic>> items}) {
    final posted = <String>[];
    var unread = items.where((n) => n['is_read'] == false).length;

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              posted.add(options.path);
              if (options.path == '/notifications/read-all') unread = 0;
              handler.resolve(
                Response(requestOptions: options, data: {'data': null}),
              );
              return;
            }
            final data = switch (options.path) {
              '/notifications' => {'data': items},
              '/notifications/unread-count' => {
                'data': {'count': unread},
              },
              _ => {'data': <dynamic>[]},
            };
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
    return (dio, posted);
  }

  Future<void> pumpCentre(WidgetTester tester, Dio dio) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opening the centre marks everything read', (tester) async {
    final (dio, posted) = fakeApi(
      items: [
        notif(1, isRead: false, convId: 'ad7_u1_u2'),
        notif(2, isRead: false),
      ],
    );

    await pumpCentre(tester, dio);

    expect(
      posted,
      contains('/notifications/read-all'),
      reason: 'reading the centre is reading the notifications',
    );
  });

  testWidgets('an all-read list is not cleared again', (tester) async {
    final (dio, posted) = fakeApi(
      items: [notif(1, isRead: true), notif(2, isRead: true)],
    );

    await pumpCentre(tester, dio);

    expect(posted, isEmpty, reason: 'nothing was unread, so nothing to clear');
  });

  testWidgets('the rows keep their unread highlight for this visit', (
    tester,
  ) async {
    final (dio, _) = fakeApi(
      items: [notif(1, isRead: false), notif(2, isRead: true)],
    );

    await pumpCentre(tester, dio);

    // Exactly one unread dot: clearing on the server must not repaint the list
    // out from under the user, or they lose track of what was new.
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.shape == BoxShape.circle &&
              d.color == const Color(0xFF6366F1);
        })
        .length;
    expect(dots, 1);
  });
}
