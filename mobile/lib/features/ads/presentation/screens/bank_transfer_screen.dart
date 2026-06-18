import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/bank_account.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/ad_api.dart';

/// Bank-transfer payment for the publish fee.
///
/// Payment gateways are not yet live, so the seller transfers the fee to the
/// company bank account (QR + details below) and uploads a screenshot of the
/// transfer. The receipt then goes to admin review before the ad is published.
class BankTransferScreen extends ConsumerStatefulWidget {
  final int adId;
  final double fee;

  const BankTransferScreen({super.key, required this.adId, required this.fee});

  @override
  ConsumerState<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends ConsumerState<BankTransferScreen> {
  XFile? _proof;
  bool _submitting = false;

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _proof = picked);
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _submit() async {
    if (_proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إرفاق صورة إيصال التحويل أولاً'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(adRepositoryProvider)
          .uploadPaymentProof(widget.adId, _proof!.path);
      if (!mounted) return;
      context.go('/ads/${widget.adId}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم استلام إيصال تحويل العمولة. سيتم اعتماده بعد مراجعة الإدارة.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGray100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'دفع عمولة البيع',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.neutralGray900,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.neutralGray700),
          onPressed: () => context.go('/ads/${widget.adId}'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Intro / fee
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: .2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'النشر مجاني، وتُستحق عمولة البيع الثابتة بعد إتمام البيع. بوابات الدفع الإلكتروني قيد التجهيز، لذا يتم سدادها حالياً عبر التحويل البنكي ثم إرفاق صورة الإيصال لمراجعتها.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: AppTheme.neutralGray700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المبلغ المطلوب',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutralGray700,
                      ),
                    ),
                    Text(
                      '${widget.fee.toStringAsFixed(0)} ر.س',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QR
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.neutralGray200),
              ),
              child: Column(
                children: [
                  Image.asset(
                    BankAccount.qrAsset,
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'امسح رمز QR من تطبيق البنك للتحويل المباشر',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutralGray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bank details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.neutralGray200),
            ),
            child: Column(
              children: [
                _detailRow('اسم المستفيد', BankAccount.accountName),
                _detailRow('البنك', BankAccount.bankName),
                _detailRow(
                  'رقم الحساب',
                  BankAccount.accountNumber,
                  copyable: true,
                ),
                _detailRow(
                  'الآيبان (IBAN)',
                  BankAccount.iban,
                  copyable: true,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Upload proof
          const Text(
            'إرفاق إيصال التحويل',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.neutralGray900,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _submitting ? null : _pickProof,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(_proof == null ? 28 : 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: .4),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: _proof == null
                  ? const Column(
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 34,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'اضغط لاختيار صورة إيصال التحويل',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppTheme.neutralGray600,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_proof!.path),
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          if (_proof != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _submitting ? null : _pickProof,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('تغيير الصورة'),
              ),
            ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('إرسال الإيصال للمراجعة'),
          ),
          const SizedBox(height: 10),
          const Text(
            'سيتم اعتماد دفع العمولة بعد التحقق من التحويل من قِبل الإدارة.',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 11.5, color: AppTheme.neutralGray500),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool copyable = false,
    bool last = false,
  }) {
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
              onPressed: () => _copy(value, label),
            ),
        ],
      ),
    );
  }
}
