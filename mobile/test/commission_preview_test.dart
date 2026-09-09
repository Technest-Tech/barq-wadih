import 'package:flutter_test/flutter_test.dart';

import 'package:barq_wadih/features/ads/data/ad_api.dart';

/// The fees card lists a showroom rate next to an individual rate, but only
/// where the category actually prices them differently — vehicle categories
/// charge dealers less. Everywhere else one line is the honest answer.
void main() {
  Map<String, dynamic> payload({
    num amount = 99,
    num? individual,
    num? dealer,
  }) => {
    'price': 100000,
    'commission_amount': amount,
    if (individual != null) 'commission_individual': individual,
    if (dealer != null) 'commission_dealer': dealer,
    'commission_rate': null,
    'is_flat_fee': true,
    'minimum_commission': null,
    'note': 'note',
  };

  test('a category that charges dealers less reports separate rates', () {
    final preview = CommissionPreviewModel.fromJson(
      payload(amount: 99, individual: 99, dealer: 35),
    );

    expect(preview.hasSeparateSellerRates, isTrue);
    expect(preview.commissionDealer, 35);
    expect(preview.commissionIndividual, 99);
  });

  test('a category charging both seller types the same reports one rate', () {
    final preview = CommissionPreviewModel.fromJson(
      payload(amount: 10, individual: 10, dealer: 10),
    );

    expect(preview.hasSeparateSellerRates, isFalse);
    expect(preview.commissionAmount, 10);
  });

  test('an older API response without the two rates still parses', () {
    final preview = CommissionPreviewModel.fromJson(payload(amount: 99));

    expect(preview.hasSeparateSellerRates, isFalse);
    expect(preview.commissionAmount, 99);
    expect(preview.commissionDealer, isNull);
  });
}
