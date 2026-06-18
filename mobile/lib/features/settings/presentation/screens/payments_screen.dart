import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/bank_account.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ads/data/ad_api.dart';
import '../../../ads/domain/ad_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// "سداد العمولات" — publishing is free; a flat commission is owed only after a
/// sale. This screen shows the company bank details (QR + account) and lists
/// the user's sold ads with their commission status, linking each unpaid one to
/// the bank-transfer receipt flow.
class PaymentsScreen extends ConsumerWidget {
  /// Kept for router compatibility (legacy fee-calculator entry points). Unused.
  final double? initialPrice;
  const PaymentsScreen({super.key, this.initialPrice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'سداد العمولات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HowItWorksCard(),
            const SizedBox(height: 16),
            const _BankAccountCard(),
            const SizedBox(height: 22),
            const Text(
              'عمولات إعلاناتك',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.neutralGray900,
              ),
            ),
            const SizedBox(height: 10),
            if (!isAuthed)
              const _Hint('سجّل الدخول لعرض العمولات المستحقة على إعلاناتك.')
            else
              const _CommissionDuesList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── How it works ──────────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primaryBlue,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'النشر مجاني',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تُستحق عمولة ثابتة (شاملة الضريبة) بعد إتمام البيع فقط. بوابات الدفع قيد التجهيز، لذا تُسدّد العمولة عبر تحويل بنكي إلى الحساب التالي ثم إرفاق صورة الإيصال لمراجعتها.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppTheme.primaryBlue.withValues(alpha: .8),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bank account card (QR + details) ──────────────────────────────────────────

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Image.asset(BankAccount.qrAsset, width: 220, fit: BoxFit.contain),
          const SizedBox(height: 8),
          const Text(
            'امسح رمز QR من تطبيق البنك للتحويل المباشر',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12, color: AppTheme.neutralGray500),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.neutralGray200),
          _DetailRow(label: 'اسم المستفيد', value: BankAccount.accountName),
          _DetailRow(label: 'البنك', value: BankAccount.bankName),
          _DetailRow(
            label: 'رقم الحساب',
            value: BankAccount.accountNumber,
            copyable: true,
          ),
          _DetailRow(
            label: 'الآيبان (IBAN)',
            value: BankAccount.iban,
            copyable: true,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final bool last;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.neutralGray200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutralGray500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.neutralGray900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 18,
                color: AppTheme.primaryBlue,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم نسخ $label'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 1200),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Commission dues list ──────────────────────────────────────────────────────

class _CommissionDuesList extends ConsumerWidget {
  const _CommissionDuesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAds = ref.watch(myAdsProvider);

    return myAds.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryBlue,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (_, __) => const _Hint('تعذّر تحميل العمولات. حاول لاحقاً.'),
      data: (ads) {
        // Sold ads that carry a commission (owed, under review, or paid).
        final dues = ads
            .where((a) => a.status == 'sold' && (a.paymentAmount ?? 0) > 0)
            .toList();

        if (dues.isEmpty) {
          return const _Hint(
            'لا توجد عمولات مستحقة حالياً. تظهر هنا بعد تحديد إعلان كمُباع.',
          );
        }

        return Column(
          children: [
            for (final ad in dues) ...[
              _DueTile(ad: ad),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _DueTile extends StatelessWidget {
  final AdListModel ad;
  const _DueTile({required this.ad});

  @override
  Widget build(BuildContext context) {
    final amount = ad.paymentAmount ?? 0;
    final status = ad.paymentStatus ?? 'pending';

    final (String label, Color color, bool payable) = switch (status) {
      'paid' => ('مدفوعة', AppTheme.colorSuccess, false),
      'under_review' => ('قيد المراجعة', AppTheme.colorWarning, false),
      _ => ('مستحقة', AppTheme.colorError, true),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ad.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.neutralGray900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'العمولة: ${amount.toStringAsFixed(0)} ر.س',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
                ),
              ),
              if (payable)
                ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/ads/${ad.id}/pay', extra: amount),
                  icon: const Icon(Icons.account_balance_rounded, size: 16),
                  label: const Text('دفع العمولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Hint ──────────────────────────────────────────────────────────────────────

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: AppTheme.neutralGray300,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.neutralGray500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
