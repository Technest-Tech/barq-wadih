import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Bottom sheet shown after a seller marks an ad as sold.
///
/// Publishing is free; a flat commission (VAT-inclusive) is owed only after the
/// sale. This sheet shows the owed commission and sends the seller to the
/// bank-transfer screen to pay it (gateways aren't live yet). When the category
/// is free (commission = 0) it's a simple congratulations sheet.
class SoldFeeSheet extends StatelessWidget {
  final int adId;
  final String adTitle;
  final double commission;

  const SoldFeeSheet({
    super.key,
    required this.adId,
    required this.adTitle,
    required this.commission,
  });

  static Future<void> show(
    BuildContext context, {
    required int adId,
    required String adTitle,
    required double commission,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SoldFeeSheet(adId: adId, adTitle: adTitle, commission: commission),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCommission = commission > 0;

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

            const Text(
              'تم البيع بنجاح!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.neutralGray900,
              ),
            ),
            const SizedBox(height: 6),

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

            if (hasCommission) ...[
              // Commission card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.neutralGray200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'عمولة المنصة المستحقة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        Text(
                          '${commission.toStringAsFixed(0)} ر.س',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'عمولة ثابتة شاملة ضريبة القيمة المضافة، تُدفع عبر تحويل بنكي ثم تُراجَع من الإدارة.',
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

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/ads/$adId/pay', extra: commission);
                  },
                  icon: const Icon(Icons.account_balance_rounded, size: 20),
                  label: const Text(
                    'دفع العمولة الآن',
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'لاحقاً',
                  style: TextStyle(
                    color: AppTheme.neutralGray500,
                    fontSize: 14,
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'هذا القسم مجاني بالكامل — لا توجد عمولة مستحقة.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.neutralGray600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text(
                    'تم',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
