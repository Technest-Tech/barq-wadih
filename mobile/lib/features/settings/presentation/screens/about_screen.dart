import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'من نحن',
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
            _buildAboutCard(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
          Image.asset(
            'assets/images/logo_nobg.png',
            height: 64,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.bolt_rounded, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'برق واضح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'منصة الإعلانات المبوبة الأولى في المملكة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'من نحن',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            'تطبيق وموقع برق واضح هو منصة إلكترونية سعودية متخصصة في مجال الإعلانات المبوبة، '
            'مملوك ومدار بالكامل من قِبل مؤسسة برق واضح المسجلة رسمياً في المملكة العربية السعودية.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.neutralGray700,
              height: 1.7,
            ),
            textDirection: TextDirection.rtl,
          ),
          SizedBox(height: 10),
          Text(
            'نهدف إلى تقديم تجربة سهلة وسريعة وموثوقة للمستخدمين لبيع وشراء السلع والمركبات '
            'بكل وضوح وأمان.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.neutralGray700,
              height: 1.7,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                Icons.business_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'المعلومات التجارية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'اسم المنشأة', value: 'مؤسسة برق واضح'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _InfoRow(
            label: 'رقم السجل التجاري',
            value: '7054134502',
            highlight: true,
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _InfoRow(
            label: 'بلد التسجيل',
            value: 'المملكة العربية السعودية 🇸🇦',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _InfoRow(
            label: 'النشاط التجاري',
            value: 'منصة إعلانات مبوبة إلكترونية',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.neutralGray500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onLongPress: highlight
                ? () => Clipboard.setData(ClipboardData(text: value))
                : null,
            child: Text(
              value,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight
                    ? AppTheme.primaryBlue
                    : AppTheme.neutralGray800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
