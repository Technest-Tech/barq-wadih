import 'package:barq_wadih/features/reports/presentation/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apple reviewed this app on an iPad Air 11-inch. The report sheet is the
/// Guideline 1.2 control surface, so its reason list, description field and
/// send button must stay reachable on every form factor — including with the
/// keyboard raised, in landscape, and at large Dynamic Type.
void main() {
  // Logical sizes / device pixel ratios for the review-relevant devices.
  const devices = <String, ({Size size, double dpr})>{
    'iPhone SE (small)': (size: Size(375, 667), dpr: 2.0),
    'iPhone 16 Pro Max (6.9")': (size: Size(440, 956), dpr: 3.0),
    'iPad Air 11" portrait': (size: Size(820, 1180), dpr: 2.0),
    'iPad Air 11" landscape': (size: Size(1180, 820), dpr: 2.0),
  };

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Size size,
    required double dpr,
    double keyboard = 0,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              devicePixelRatio: dpr,
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              viewInsets: EdgeInsets.only(bottom: keyboard),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ReportSheet(adId: 1),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The submit button must be inside the viewport and actually tappable.
  void expectSendButtonUsable(WidgetTester tester, Size size) {
    final send = find.widgetWithText(ElevatedButton, 'إرسال البلاغ');
    expect(send, findsOneWidget, reason: 'send button must be rendered');

    final rect = tester.getRect(send);
    expect(rect.height, greaterThan(30), reason: 'send button must not be collapsed');
    expect(rect.bottom, lessThanOrEqualTo(size.height + 0.5),
        reason: 'send button must not sit below the screen');
    expect(rect.top, greaterThanOrEqualTo(-0.5),
        reason: 'send button must not sit above the screen');
  }

  for (final entry in devices.entries) {
    final name = entry.key;
    final size = entry.value.size;
    final dpr = entry.value.dpr;

    testWidgets('$name — renders with the send button reachable', (tester) async {
      await pumpSheet(tester, size: size, dpr: dpr);

      expect(find.text('الإبلاغ عن الإعلان'), findsOneWidget);
      expect(find.text('🚫 إعلان مزيف'), findsOneWidget);
      expectSendButtonUsable(tester, size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name — send button stays reachable with the keyboard up', (tester) async {
      await pumpSheet(tester, size: size, dpr: dpr, keyboard: size.height * 0.4);

      expectSendButtonUsable(tester, size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name — survives large Dynamic Type', (tester) async {
      await pumpSheet(tester, size: size, dpr: dpr, textScale: 1.6);

      expectSendButtonUsable(tester, size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name — every reason is reachable by scrolling', (tester) async {
      await pumpSheet(tester, size: size, dpr: dpr);

      final list = find.byType(ListView);
      expect(list, findsOneWidget);

      // The last reason and the optional description sit at the bottom of the
      // scrollable; both must be reachable without leaving the sheet.
      await tester.scrollUntilVisible(find.text('❓ أخرى'), 120, scrollable: find.byType(Scrollable).first);
      expect(find.text('❓ أخرى'), findsOneWidget);

      await tester.tap(find.text('❓ أخرى'));
      await tester.pumpAndSettle();

      expectSendButtonUsable(tester, size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selecting a reason and typing a description keeps the form intact', (tester) async {
    await pumpSheet(tester, size: const Size(820, 1180), dpr: 2.0);

    await tester.tap(find.text('⚠️ احتيال'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'تفاصيل الاختبار');
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الاختبار'), findsOneWidget);
    expectSendButtonUsable(tester, const Size(820, 1180));
    expect(tester.takeException(), isNull);
  });
}
