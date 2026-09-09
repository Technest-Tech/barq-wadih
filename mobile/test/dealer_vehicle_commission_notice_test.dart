import 'package:barq_wadih/features/ads/presentation/widgets/dealer_vehicle_commission_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dealer vehicle commission notice fits a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: DealerVehicleCommissionNotice()),
        ),
      ),
    );

    expect(find.textContaining('٣٥ ريالًا'), findsOneWidget);
    expect(find.textContaining('وتكون في الذمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
