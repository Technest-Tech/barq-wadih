import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:barq_wadih/shared/widgets/share_account_sheet.dart';

const _account = ShareAccountData(
  name: 'أحمد عمر',
  username: 'ahmd_aamr',
  profileUrl: 'https://barqwadih.com/@ahmd_aamr',
);

Future<void> _openSheet(WidgetTester tester, {ShareAccountData? account}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () =>
                showShareAccountSheet(context, account: account ?? _account),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the account identity, handle and link', (tester) async {
    await _openSheet(tester);

    expect(find.text('مشاركة الحساب'), findsOneWidget);
    expect(find.text('أحمد عمر'), findsOneWidget);
    expect(find.text('@ahmd_aamr'), findsOneWidget);
    // The link is shown without its scheme, the way the reference app does.
    expect(find.text('barqwadih.com/@ahmd_aamr'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('copies the link to the clipboard when tapped', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await _openSheet(tester);
    await tester.tap(find.text('barqwadih.com/@ahmd_aamr'));
    await tester.pump();

    expect(copied, 'https://barqwadih.com/@ahmd_aamr');
    expect(find.text('تم نسخ رابط الحساب'), findsOneWidget);
  });

  testWidgets('offers the expected share targets', (tester) async {
    await _openSheet(tester);

    for (final label in ['واتساب', 'اكس', 'سناب', 'انستقرام', 'فيسبوك', 'ماسنجر']) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label');
    }
    // Always a way out to the system sheet for anything not listed.
    expect(find.text('المزيد'), findsOneWidget);
  });

  testWidgets('still renders for an account without a handle', (tester) async {
    await _openSheet(
      tester,
      account: const ShareAccountData(
        name: 'بائع',
        profileUrl: 'https://barqwadih.com/users/42',
      ),
    );

    expect(find.text('بائع'), findsOneWidget);
    expect(find.text('barqwadih.com/users/42'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });
}
