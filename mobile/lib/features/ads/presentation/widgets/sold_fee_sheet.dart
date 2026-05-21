import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Bottom sheet shown after a seller marks an ad as sold.
/// Displays the 5% fee breakdown and lets the seller navigate
/// to the payments calculator with the ad price pre-filled.
class SoldFeeSheet extends StatelessWidget {
  final String adTitle;
  final double? adPrice;

  const SoldFeeSheet({super.key, required this.adTitle, required this.adPrice});

  static Future<void> show(
    BuildContext context, {
    required String adTitle,
    required double? adPrice,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoldFeeSheet(adTitle: adTitle, adPrice: adPrice),
    );
  }

  static const double _feeRate = 0.05;

  double get _fee => (adPrice ?? 0) * _feeRate;

  @override
  Widget build(BuildContext context) {
    final hasPrice = adPrice != null && adPrice! > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.neutralGray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Success icon
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 40,
              ),
            ),
            const SizedBox(height: 14),

            // Title
            const Text(
              'تم البيع بنجاح!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.neutralGray900,
              ),
            ),
            const SizedBox(height: 6),

            // Ad title
            Text(
              adTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.neutralGray500,
              ),
            ),
            const SizedBox(height: 20),

            // Fee breakdown card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.neutralGray50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.neutralGray200),
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'رسوم المنصة المستحقة',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (hasPrice) ...[
                    _FeeRow(
                      label: 'سعر البيع',
                      value: '${adPrice!.toStringAsFixed(0)} ر.س',
                    ),
                    const SizedBox(height: 8),
                    _FeeRow(
                      label: 'رسوم المنصة (5%)',
                      value: '${_fee.toStringAsFixed(2)} ر.س',
                      valueColor: const Color(0xFFEA580C),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppTheme.neutralGray200),
                    ),
                    _FeeRow(
                      label: 'الإجمالي المستحق',
                      value: '${_fee.toStringAsFixed(2)} ر.س',
                      isTotal: true,
                    ),
                  ] else
                    const Text(
                      'سيتم احتساب الرسوم بنسبة 5% من سعر البيع عند الدفع.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutralGray600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pay now button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/payments', extra: adPrice);
                },
                icon: const Icon(Icons.calculate_outlined, size: 20),
                label: const Text(
                  'احسب الرسوم وادفع الآن',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Later button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'لاحقاً',
                style: TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  const _FeeRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
            color: isTotal ? AppTheme.neutralGray800 : AppTheme.neutralGray600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: FontWeight.w700,
            color:
                valueColor ??
                (isTotal ? AppTheme.primaryBlue : AppTheme.neutralGray800),
          ),
        ),
      ],
    );
  }
}
