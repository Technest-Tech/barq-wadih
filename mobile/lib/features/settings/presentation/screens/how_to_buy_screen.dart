import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class HowToBuyScreen extends StatelessWidget {
  const HowToBuyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'كيف تشتري؟',
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
            _buildTipsSection(),
            const SizedBox(height: 20),
            _buildWarningsSection(),
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
          colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 52),
          SizedBox(height: 12),
          Text(
            'دليل الشراء في برق واضح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'خطوات سهلة وآمنة للعثور على أفضل الصفقات',
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
                'خطوات الشراء',
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
                'نصائح ذهبية للمشتري',
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
                    color: Color(0xFF16A34A),
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

  Widget _buildWarningsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEA580C),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'احذر من هذه الأمور',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final warning in _warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF92400E),
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
      Icons.search_rounded,
      'ابحث عن المنتج',
      'استخدم شريط البحث أو تصفح الفئات للعثور على المنتج الذي تريده. يمكنك تصفية النتائج حسب الموقع والسعر والحالة.',
    ),
    (
      Icons.visibility_rounded,
      'راجع الإعلان بعناية',
      'اقرأ وصف المنتج بالكامل، تحقق من جميع الصور، واطلع على تقييمات البائع وتاريخ حسابه.',
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'تواصل مع البائع',
      'اضغط على "تواصل مع البائع" وتحدث معه عبر نظام الرسائل الداخلي. يمكنك الاتصال المباشر أيضاً إذا أتاح البائع رقمه.',
    ),
    (
      Icons.handshake_outlined,
      'تفاوض على السعر',
      'يمكنك التفاوض على السعر بشكل مباشر مع البائع. تأكد من الاتفاق على جميع التفاصيل قبل الموافقة.',
    ),
    (
      Icons.location_on_outlined,
      'حدد مكان الاستلام',
      'تفق مع البائع على مكان الاستلام في منطقة عامة ومضاءة. مراكز التسوق والأماكن المكشوفة هي الأفضل.',
    ),
    (
      Icons.check_circle_outline_rounded,
      'افحص المنتج واستلمه',
      'افحص المنتج جيداً قبل دفع أي مبلغ. تأكد من مطابقته للوصف ثم أتمم الصفقة.',
    ),
  ];

  static const _tips = [
    'قارن أسعار عدة إعلانات مشابهة قبل اتخاذ قرار الشراء.',
    'اطلع على تقييمات البائع وتحقق من كونه موثقاً.',
    'لا تدفع أي مبلغ مسبقاً قبل الفحص الشخصي للمنتج.',
    'التقِ بالبائع في الأماكن العامة دائماً.',
    'احتفظ بسجل المحادثات داخل التطبيق كإثبات للاتفاق.',
    'للمنتجات ذات القيمة العالية، استخدم خدمة الشراء الموثوق.',
  ];

  static const _warnings = [
    'لا تحول أي مبلغ مالي قبل استلام المنتج ورؤيته شخصياً.',
    'احذر من الأسعار المنخفضة جداً بشكل غير منطقي — قد تكون عمليات احتيال.',
    'لا تشارك بياناتك البنكية أو كلمات المرور مع أحد.',
    'تجنب الروابط الخارجية التي يرسلها البائع خارج التطبيق.',
    'البائع الحقيقي لا يطلب منك الدفع عبر تحويل بنكي فوري قبل الاستلام.',
  ];
}
