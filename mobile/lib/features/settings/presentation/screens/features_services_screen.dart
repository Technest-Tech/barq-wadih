import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        title: const Text('مميزات وخدمات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 20),
            _buildSectionTitle('مقارنة الباقات'),
            const SizedBox(height: 10),
            _buildPlanComparisonTable(),
            const SizedBox(height: 20),
            _buildUpgradeCta(context),
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
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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
          fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.neutralGray800),
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
      IconData icon, String title, String desc, Color color) {
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
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutralGray800)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.neutralGray500, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanComparisonTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        children: [
          _buildTableHeader(),
          for (final (i, row) in _comparisonRows.indexed)
            _buildTableRow(row.$1, row.$2, row.$3, row.$4, i.isOdd),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: AppTheme.primaryBlue),
      children: [
        _tableCell('الميزة', isHeader: true),
        _tableCell('مجاني', isHeader: true),
        _tableCell('أساسي', isHeader: true),
        _tableCell('احترافي', isHeader: true),
      ],
    );
  }

  TableRow _buildTableRow(
      String feature, String free, String basic, String pro, bool shaded) {
    return TableRow(
      decoration: BoxDecoration(
          color: shaded ? AppTheme.neutralGray50 : Colors.white),
      children: [
        _tableCell(feature, isFeature: true),
        _tableCell(free),
        _tableCell(basic),
        _tableCell(pro, highlight: true),
      ],
    );
  }

  Widget _tableCell(String text,
      {bool isHeader = false, bool isFeature = false, bool highlight = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: text == '✓' || text == '✗'
            ? Center(
                child: Icon(
                  text == '✓' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 16,
                  color: text == '✓'
                      ? AppTheme.colorSuccess
                      : AppTheme.neutralGray300,
                ),
              )
            : Text(
                text,
                textAlign: isFeature ? TextAlign.start : TextAlign.center,
                style: TextStyle(
                  fontSize: isHeader ? 11 : 12,
                  fontWeight: isHeader || isFeature
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isHeader
                      ? Colors.white
                      : highlight && !isFeature
                          ? AppTheme.accentGold
                          : AppTheme.neutralGray700,
                ),
              ),
      ),
    );
  }

  Widget _buildUpgradeCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.rocket_launch_rounded,
              color: AppTheme.accentGold, size: 36),
          const SizedBox(height: 10),
          const Text(
            'طوّر حسابك الآن',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'احصل على باقة احترافية وتميّز بين آلاف الإعلانات',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => context.push('/payments'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('ترقية الحساب'),
          ),
        ],
      ),
    );
  }

  static const _features = <(IconData, String, String, Color)>[
    (
      Icons.trending_up_rounded,
      'تعزيز الإعلان',
      'ضع إعلانك في الصدارة',
      AppTheme.primaryBlue
    ),
    (
      Icons.verified_rounded,
      'الشراء الموثوق',
      'اشترِ بأمان تام',
      AppTheme.accentGold
    ),
    (
      Icons.refresh_rounded,
      'تجديد الإعلان',
      'عدّل ترتيب إعلانك',
      Color(0xFF16A34A)
    ),
    (
      Icons.star_rounded,
      'التقييمات',
      'بنِ سمعة موثوقة',
      Color(0xFFEA580C)
    ),
    (
      Icons.chat_bubble_rounded,
      'الرسائل الفورية',
      'تواصل مباشرة',
      Color(0xFF0284C7)
    ),
    (
      Icons.local_offer_rounded,
      'عروض مميزة',
      'خصومات حصرية للمشتركين',
      Color(0xFF9333EA)
    ),
  ];

  static const _comparisonRows = <(String, String, String, String)>[
    ('الإعلانات النشطة', '3', '10', 'غير محدود'),
    ('تعزيز الإعلان', '✗', '✓', '✓'),
    ('تجديد الإعلان', '✗', '✓', '✓'),
    ('الشراء الموثوق', '✗', '✗', '✓'),
    ('دعم مميز', '✗', '✓', '✓'),
    ('إحصائيات تفصيلية', '✗', '✗', '✓'),
  ];
}
