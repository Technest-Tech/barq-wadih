import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barq_wadih/core/network/api_client.dart';
import 'package:barq_wadih/features/auth/domain/auth_user.dart';
import 'package:barq_wadih/features/auth/presentation/providers/auth_provider.dart';
import 'package:barq_wadih/features/questions/presentation/widgets/ad_comments_section.dart';

/// The ad detail page replaced its star-rating block with these comments, so
/// the section carries the whole buyer↔seller Q&A: anyone signed in may ask,
/// and only the ad's owner gets the reply affordance.
void main() {
  const adId = 7;
  const sellerId = 42;
  const buyerId = 99;

  Map<String, dynamic> question({
    required int id,
    required String body,
    required int userId,
    required String userName,
    List<Map<String, dynamic>> replies = const [],
  }) => {
    'id': id,
    'body': body,
    'user': {'id': userId, 'name': userName, 'avatar': null},
    'replies': replies,
    'created_at': '2026-09-01T10:00:00Z',
  };

  /// Serves one question with a seller reply, and records what gets posted.
  (Dio, List<({String path, Object? body})>) fakeApi() {
    final posted = <({String path, Object? body})>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              posted.add((
                path: options.path,
                body: (options.data as Map?)?['body'],
              ));
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'data': question(
                      id: 100,
                      body: '${(options.data as Map)['body']}',
                      userId: buyerId,
                      userName: 'مشتري',
                    ),
                  },
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    question(
                      id: 1,
                      body: 'هل السعر قابل للتفاوض؟',
                      userId: buyerId,
                      userName: 'أحمد',
                      replies: [
                        question(
                          id: 2,
                          body: 'نعم، تفضل بالتواصل.',
                          userId: sellerId,
                          userName: 'البائع محمد',
                        ),
                      ],
                    ),
                  ],
                },
              ),
            );
          },
        ),
      );
    return (dio, posted);
  }

  Future<void> pumpSection(
    WidgetTester tester,
    Dio dio, {
    AuthUser? currentUser,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          currentUserProvider.overrideWithValue(currentUser),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: AdCommentsSection(adId: adId, sellerId: sellerId),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AuthUser user(int id, String name) => AuthUser(
    id: id,
    name: name,
    role: 'user',
    locale: 'ar',
    isVerified: true,
    isDealer: false,
    isActive: true,
    avgRating: '0',
    ratingCount: 0,
    totalAdsCount: 0,
    unreadNotificationsCount: 0,
    createdAt: '2026-01-01T00:00:00Z',
  );

  testWidgets('renders each comment with its replies and the composer', (
    tester,
  ) async {
    final (dio, _) = fakeApi();
    await pumpSection(tester, dio);

    expect(find.text('الأسئلة والاستفسارات'), findsOneWidget);
    expect(find.text('هل السعر قابل للتفاوض؟'), findsOneWidget);
    expect(find.text('نعم، تفضل بالتواصل.'), findsOneWidget);
    // The seller's own reply is badged as such.
    expect(find.text('البائع'), findsOneWidget);
    // Anyone can ask — the composer is always mounted.
    expect(find.text('اكتب سؤالك للعارض'), findsOneWidget);
  });

  testWidgets('only the ad owner sees the reply affordance', (tester) async {
    final (visitorDio, _) = fakeApi();
    await pumpSection(tester, visitorDio, currentUser: user(buyerId, 'أحمد'));
    expect(
      find.widgetWithText(TextButton, 'رد'),
      findsNothing,
      reason: 'a buyer must not be offered the seller reply box',
    );

    final (sellerDio, _) = fakeApi();
    await pumpSection(tester, sellerDio, currentUser: user(sellerId, 'محمد'));
    expect(find.widgetWithText(TextButton, 'رد'), findsOneWidget);
  });

  testWidgets('a signed-in visitor can post a comment', (tester) async {
    final (dio, posted) = fakeApi();
    await pumpSection(tester, dio, currentUser: user(buyerId, 'أحمد'));

    await tester.enterText(
      find.byType(TextField).last,
      'هل التوصيل متوفر؟',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'إرسال'));
    await tester.pumpAndSettle();

    expect(posted, hasLength(1));
    expect(posted.single.path, '/ads/$adId/questions');
    expect(posted.single.body, 'هل التوصيل متوفر؟');
    expect(find.text('✓ تم إرسال سؤالك'), findsOneWidget);
  });

  testWidgets('the seller replies through the inline reply box', (
    tester,
  ) async {
    final (dio, posted) = fakeApi();
    await pumpSection(tester, dio, currentUser: user(sellerId, 'محمد'));

    await tester.tap(find.widgetWithText(TextButton, 'رد'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'نعم متوفر.');
    await tester.tap(find.widgetWithText(ElevatedButton, 'إرسال الرد'));
    await tester.pumpAndSettle();

    expect(posted, hasLength(1));
    expect(posted.single.path, '/questions/1/reply');
    expect(posted.single.body, 'نعم متوفر.');
  });
}
