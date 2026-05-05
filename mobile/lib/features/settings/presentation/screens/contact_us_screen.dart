import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('اتصل بنا',
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
            _buildSectionTitle('تواصل معنا مباشرة'),
            const SizedBox(height: 10),
            _buildContactCard(
              icon: Icons.chat_rounded,
              iconBg: const Color(0xFF25D366),
              label: 'واتساب',
              subtitle: '+966 50 000 0000',
              onTap: () => _launch('https://wa.me/+966500000000'),
            ),
            const SizedBox(height: 8),
            _buildContactCard(
              icon: Icons.phone_rounded,
              iconBg: AppTheme.primaryBlue,
              label: 'اتصل بنا',
              subtitle: '+966 50 000 0000',
              onTap: () => _launch('tel:+966500000000'),
            ),
            const SizedBox(height: 8),
            _buildContactCard(
              icon: Icons.email_rounded,
              iconBg: const Color(0xFFEA4335),
              label: 'البريد الإلكتروني',
              subtitle: 'support@barqwadih.com',
              onTap: () => _launch('mailto:support@barqwadih.com'),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('تابعنا على السوشيال ميديا'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSocialCard(
                    label: 'تويتر / X',
                    icon: Icons.alternate_email_rounded,
                    color: const Color(0xFF1DA1F2),
                    onTap: () => _launch('https://twitter.com/barqwadih'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSocialCard(
                    label: 'انستغرام',
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFFE1306C),
                    onTap: () => _launch('https://instagram.com/barqwadih'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildWorkingHoursCard(),
            const SizedBox(height: 20),
            _buildResponseTimeCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Icon(Icons.support_agent_rounded, color: Colors.white, size: 48),
          SizedBox(height: 12),
          Text(
            'فريق دعم برق واضح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'نحن هنا لمساعدتك في أي وقت',
            textAlign: TextAlign.center,
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

  Widget _buildContactCard({
    required IconData icon,
    required Color iconBg,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.neutralGray500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.neutralGray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neutralGray800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    const hours = [
      ('السبت – الأربعاء', '9:00 صباحاً – 10:00 مساءً'),
      ('الخميس – الجمعة', '10:00 صباحاً – 8:00 مساءً'),
    ];

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
              Icon(Icons.schedule_rounded,
                  color: AppTheme.primaryBlue, size: 20),
              SizedBox(width: 8),
              Text('ساعات الدعم',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.neutralGray800)),
            ],
          ),
          const SizedBox(height: 12),
          for (final (day, time) in hours) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.neutralGray600)),
                Text(time,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutralGray800)),
              ],
            ),
            if (day != hours.last.$1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseTimeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: .3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_rounded, color: AppTheme.accentGold, size: 22),
          SizedBox(width: 10),
          Text(
            'متوسط وقت الرد: ساعة واحدة',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralGray800),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
