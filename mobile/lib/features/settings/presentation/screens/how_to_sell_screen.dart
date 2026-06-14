import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class HowToSellScreen extends StatelessWidget {
  const HowToSellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'كيف تبيع؟',
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
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildStepsSection(),
            const SizedBox(height: 20),
            _buildFeesSection(),
            const SizedBox(height: 20),
            _buildTipsSection(),
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
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.sell_rounded, color: Colors.white, size: 52),
          SizedBox(height: 12),
          Text(
            'دليل البيع في برق واضح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'انشر إعلانك الآن وابيع بسرعة وأمان',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
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
              Icon(
                Icons.format_list_numbered_rounded,
                color: AppTheme.primaryBlue,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'خطوات نشر الإعلان',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, step) in _steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildStep(i + 1, step.$1, step.$2, step.$3),
            ),
        ],
      ),
    );
  }

  Widget _buildStep(
    int number,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppTheme.primaryBlue, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeesSection() {
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
              Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF0D9488),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'الرسوم والعمولات',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D9488),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final fee in _fees)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_outlined,
                      color: Color(0xFF0D9488),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fee,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF134E4A),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
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
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'نصائح لبيع أسرع',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutralGray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final tip in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutralGray700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _steps = <(IconData, String, String)>[
    (
      Icons.account_circle_outlined,
      'أنشئ حساباً أو سجّل الدخول',
      'يجب تسجيل الدخول أولاً. إذا لم يكن لديك حساب، يمكنك إنشاء واحد مجاناً في ثوانٍ عبر رقم الجوال.',
    ),
    (
      Icons.add_circle_outline_rounded,
      'اضغط على "نشر إعلان"',
      'اضغط على زر "+" في الشريط السفلي للانتقال لشاشة نشر إعلان جديد.',
    ),
    (
      Icons.category_outlined,
      'اختر الفئة المناسبة',
      'حدد فئة المنتج الصحيحة (إلكترونيات، سيارات، أثاث...). اختيار الفئة الصحيحة يزيد فرص الظهور للمشترين.',
    ),
    (
      Icons.photo_library_outlined,
      'أضف صوراً واضحة',
      'التقط صوراً حقيقية للمنتج من زوايا متعددة في إضاءة جيدة. الإعلانات ذات الصور الواضحة تُباع أسرع بـ 3 مرات.',
    ),
    (
      Icons.description_outlined,
      'اكتب وصفاً دقيقاً',
      'اذكر حالة المنتج، المميزات، وأي عيوب إن وجدت. الصدق يبني ثقة المشتري ويُسرّع إتمام الصفقة.',
    ),
    (
      Icons.price_change_outlined,
      'حدد سعراً مناسباً',
      'ابحث عن أسعار مشابهة في المنصة وحدد سعراً تنافسياً. يمكنك قبول التفاوض للبيع أسرع.',
    ),
    (
      Icons.publish_rounded,
      'انشر الإعلان',
      'بعد مراجعة جميع التفاصيل ودفع رسوم النشر، سيظهر إعلانك للمشترين فوراً.',
    ),
  ];

  static const _fees = [
    '🚗 السيارات والمركبات: رسوم النشر 99 ر.س للإعلان.',
    '📱 الجوالات والأقسام الأخرى: رسوم النشر 10 ر.س للإعلان.',
    '💼 الوظائف: النشر مجاني.',
    'رسوم النشر تُدفع مقدمًا عند إنشاء الإعلان وهي غير مستردة.',
    'يمكن تجديد الإعلان (رفعه للأعلى) مرة واحدة كل 24 ساعة.',
    'الإعلانات النشطة تنتهي صلاحيتها بعد 30 يومًا من تاريخ النشر.',
  ];

  static const _tips = [
    'استخدم الكلمات التي يبحث عنها المشترون في عنوان الإعلان.',
    'انشر إعلانك في ساعات الذروة (المساء وعطلة نهاية الأسبوع).',
    'استجب لرسائل المشترين بسرعة لزيادة فرص البيع.',
    'جدّد إعلانك يومياً للحفاظ على ظهوره في صدر النتائج.',
    'اذكر موقع التسليم في الإعلان لاستقطاب المشترين القريبين.',
    'أضف أكبر قدر ممكن من الصور لإعطاء المشتري صورة واضحة.',
  ];
}
