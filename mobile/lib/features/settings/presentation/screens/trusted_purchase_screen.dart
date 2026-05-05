import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class TrustedPurchaseScreen extends StatelessWidget {
  const TrustedPurchaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('الشراء الموثوق',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildHowItWorksSection(),
            const SizedBox(height: 20),
            _buildGuaranteesSection(),
            const SizedBox(height: 20),
            _buildCategoriesSection(),
            const SizedBox(height: 20),
            _buildCtaSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentGold, Color(0xFFE8960A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.verified_rounded, color: Colors.white, size: 52),
          SizedBox(height: 12),
          Text(
            'خدمة الشراء الموثوق',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'نشتري بدلاً عنك ونضمن لك المنتج الأصلي',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text('كيف تعمل الخدمة؟',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, step) in _steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildStep(i + 1, step.$1, step.$2),
            ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.neutralGray800)),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutralGray500,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuaranteesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: AppTheme.accentGold, size: 20),
              SizedBox(width: 8),
              Text('ضماناتنا لك',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.neutralGray800)),
            ],
          ),
          const SizedBox(height: 12),
          for (final guarantee in _guarantees)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.accentGold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(guarantee,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.neutralGray700, height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    const cats = [
      'إلكترونيات', 'سيارات', 'أثاث', 'ملابس',
      'هواتف', 'أجهزة منزلية',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الفئات المدعومة',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutralGray800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats
              .map(
                (cat) => Chip(
                  label: Text(cat,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: .08),
                  side: BorderSide(
                      color: AppTheme.primaryBlue.withValues(alpha: .2)),
                  labelStyle:
                      const TextStyle(color: AppTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: .06),
            AppTheme.accentGold.withValues(alpha: .06),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: .15)),
      ),
      child: Column(
        children: [
          const Text(
            'هل تريد استخدام الخدمة؟',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutralGray800),
          ),
          const SizedBox(height: 6),
          const Text(
            'تواصل مع فريقنا وسنرشدك لاستكمال طلب الشراء الموثوق.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.neutralGray600,
                height: 1.5),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => context.push('/contact-us'),
            icon: const Icon(Icons.verified_rounded, size: 16),
            label: const Text('ابدأ شراءً موثوقاً'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static const _steps = <(String, String)>[
    (
      'طلب الشراء',
      'أرسل لنا رابط الإعلان الذي تريد شراءه وسنتحقق منه فوراً.'
    ),
    (
      'التحقق والفحص',
      'يقوم فريقنا بفحص المنتج والتحقق من صحة وصف الإعلان.'
    ),
    (
      'الدفع الآمن',
      'يُدفع المبلغ بشكل آمن ولا يُحوَّل للبائع إلا بعد التسليم.'
    ),
    (
      'التسليم والضمان',
      'تستلم المنتج مفحوصاً مع ضمان استرجاع كامل إن لم يطابق الوصف.'
    ),
  ];

  static const _guarantees = [
    'فحص المنتج قبل الدفع للبائع',
    'ضمان مطابقة المنتج للوصف في الإعلان',
    'استرجاع كامل المبلغ في حال عدم مطابقة المنتج',
    'حماية كاملة من الاحتيال والغش',
    'دعم مخصص على مدار الساعة',
    'تغطية شاملة للمنتجات الإلكترونية والسيارات والأثاث',
  ];
}
