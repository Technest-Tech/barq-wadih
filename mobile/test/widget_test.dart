import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barq_wadih/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BarqWadihApp(),
      ),
    );
    // Verify the Arabic app name renders
    expect(find.text('برق واضح'), findsAny);
  });
}
