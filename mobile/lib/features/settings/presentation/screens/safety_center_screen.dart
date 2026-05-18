import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('مركز الأمان',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
            _buildTipsSection(
              title: 'نصائح للبائع',
              icon: Icons.sell_rounded,
              color: AppTheme.primaryBlue,
              tips: _sellerTips,
            ),
            const SizedBox(height: 16),
            _buildTipsSection(
              title: 'نصائح للمشتري',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFF0284C7),
              tips: _buyerTips,
            ),
            const SizedBox(height: 20),
            _buildReportCard(),
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
          colors: [Color(0xFF0F5132), Color(0xFF16A34A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: 52),
          SizedBox(height: 12),
          Text(
            'ابق آمناً في برق واضح',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'نلتزم بتوفير بيئة آمنة وموثوقة لجميع المستخدمين.\nاتبع هذه النصائح لتجربة آمنة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<(IconData, String, String)> tips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTipCard(tip.$1, tip.$2, tip.$3, color),
            )),
      ],
    );
  }

  Widget _buildTipCard(
      IconData icon, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
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
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutralGray600,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.colorError.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.colorError.withValues(alpha: .2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.report_problem_rounded,
              color: AppTheme.colorError, size: 32),
          const SizedBox(height: 8),
          const Text(
            'تعرضت لعملية احتيال؟',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.colorError),
          ),
          const SizedBox(height: 6),
          const Text(
            'في حال التعرض للاحتيال، يُرجى التواصل مع الجهات الأمنية المختصة (الشرطة أو نظام أبشر).',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.neutralGray600,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  static const _sellerTips = <(IconData, String, String)>[
    (
      Icons.photo_camera_rounded,
      'استخدم صوراً واضحة وحقيقية',
      'التقط صوراً واضحة للمنتج من زوايا متعددة لتعزيز الثقة وزيادة فرص البيع.'
    ),
    (
      Icons.description_rounded,
      'كن دقيقاً في وصف المنتج',
      'اذكر الحالة الفعلية للمنتج بصدق، بما في ذلك أي عيوب أو مشاكل موجودة.'
    ),
    (
      Icons.location_on_rounded,
      'اختر مكان التسليم بعناية',
      'التقِ بالمشتري في أماكن عامة ومضاءة جيداً، وتجنب التسليم في الأماكن المعزولة.'
    ),
    (
      Icons.payments_rounded,
      'استلم المبلغ قبل التسليم',
      'تأكد من استلام المبلغ كاملاً قبل تسليم المنتج، وتجنب قبول الشيكات.'
    ),
    (
      Icons.verified_user_rounded,
      'تعامل مع المشترين الموثقين',
      'فضّل التعامل مع المستخدمين الذين لديهم تقييمات جيدة وحسابات موثقة.'
    ),
  ];

  static const _buyerTips = <(IconData, String, String)>[
    (
      Icons.search_rounded,
      'ابحث عن البائع وتحقق منه',
      'اطلع على تقييمات البائع وتاريخ حسابه قبل إتمام أي صفقة.'
    ),
    (
      Icons.visibility_rounded,
      'افحص المنتج قبل الشراء',
      'تأكد من فحص المنتج شخصياً قبل دفع أي مبلغ، لا تدفع مقابل شيء لم تره.'
    ),
    (
      Icons.public_rounded,
      'التقِ في أماكن عامة',
      'اختر دائماً مكاناً عاماً ومكشوفاً للقاء البائع، وأبلغ شخصاً تثق به بمكانك.'
    ),
    (
      Icons.link_off_rounded,
      'احذر من الروابط والطلبات المشبوهة',
      'لا تنقر على روابط خارجية أو تُشارك بياناتك البنكية مع أي شخص.'
    ),
    (
      Icons.shield_rounded,
      'استخدم خدمة الشراء الموثوق',
      'للمنتجات ذات القيمة العالية، استخدم خدمة الشراء الموثوق للحماية الكاملة.'
    ),
  ];
}
