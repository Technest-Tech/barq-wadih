import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class FeaturesServicesScreen extends StatelessWidget {
  const FeaturesServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'مميزات وخدمات',
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
            _buildHeroBanner(),
            const SizedBox(height: 20),
            _buildSectionTitle('مميزات المنصة'),
            const SizedBox(height: 10),
            _buildFeaturesGrid(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
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
      child: Column(
        children: [
          Image.asset('assets/images/logo_nobg.png', height: 52),
          const SizedBox(height: 12),
          const Text(
            'برق واضح — منصة الإعلانات الأولى',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اكتشف كل ما يجعل تجربتك أفضل',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.neutralGray800,
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: _features
          .map((f) => _buildFeatureCard(f.$1, f.$2, f.$3, f.$4))
          .toList(),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String desc,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: .6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.neutralGray800,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.neutralGray500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _features = <(IconData, String, String, Color)>[
    (
      Icons.post_add_rounded,
      'نشر مجاني',
      'انشر إعلانك دون رسوم مسبقة',
      AppTheme.primaryBlue,
    ),
    (
      Icons.verified_rounded,
      'الشراء الموثوق',
      'اشترِ بأمان تام',
      AppTheme.accentGold,
    ),
    (
      Icons.refresh_rounded,
      'تجديد الإعلان',
      'عدّل ترتيب إعلانك',
      Color(0xFF16A34A),
    ),
    (Icons.star_rounded, 'التقييمات', 'بنِ سمعة موثوقة', Color(0xFFEA580C)),
    (
      Icons.chat_bubble_rounded,
      'الرسائل الفورية',
      'تواصل مباشرة',
      Color(0xFF0284C7),
    ),
    (
      Icons.report_outlined,
      'بلاغات وحظر',
      'أدوات واضحة لحماية المستخدمين',
      Color(0xFF9333EA),
    ),
  ];
}
