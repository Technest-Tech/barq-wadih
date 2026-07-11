import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'شروط الاستخدام',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.gavel_rounded, color: Colors.white, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'شروط وأحكام برق واضح',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'يُرجى قراءة هذه الشروط بعناية قبل استخدام المنصة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSection(
              icon: Icons.info_outline_rounded,
              title: 'عن المنصة',
              color: AppTheme.primaryBlue,
              content:
                  'برق واضح منصة إعلانات مبوبة تتيح للأفراد والتجار نشر إعلاناتهم للبيع والشراء في المملكة العربية السعودية. '
                  'المنصة وسيط إلكتروني فقط ولا تتحمل مسؤولية الصفقات المنجزة بين المستخدمين.',
            ),
            const SizedBox(height: 12),

            _buildSection(
              icon: Icons.money_outlined,
              title: 'عمولات المنصة ⚖️',
              color: const Color(0xFF0D9488),
              content:
                  'تُستحق العمولة في ذمة المعلن فور إتمام عملية البيع:\n\n'
                  '🚗 السيارات والمركبات: 99 ر.س (تُدفع بعد البيع)\n'
                  '📱 الجوالات والأقسام الأخرى: 10 ر.س (تُدفع بعد البيع)\n'
                  '💼 الوظائف: مجاني بالكامل\n\n'
                  '• جميع الأسعار تشمل ضريبة القيمة المضافة 15%.\n'
                  '• نشر الإعلان مجاني تماماً لجميع الأقسام.\n'
                  '• الإعلان ينتهي بعد 30 يوماً ويمكن تجديده مجاناً.',
            ),
            const SizedBox(height: 12),

            _buildSection(
              icon: Icons.block_rounded,
              title: 'الممنوعات — ما لا يُسمح بنشره',
              color: const Color(0xFFDC2626),
              content:
                  '🚫 العقارات بكافة أنواعها (بيع، شراء، إيجار، تأجير)\n'
                  '🚫 الأسلحة بجميع أنواعها (بنادق، مسدسات، ذخائر، سكاكين قتالية)\n'
                  '🚫 المخدرات والمؤثرات العقلية والكحول\n'
                  '🚫 الدعوة للتبرع أو المساعدات المالية\n'
                  '🚫 خدمات الوساطة في الأسهم أو تداول العملات\n'
                  '🚫 إعلانات المشاريع الاستثمارية الوهمية أو الهرم التسويقي\n'
                  '🚫 المواد الإباحية أو المخلة بالآداب العامة\n'
                  '🚫 الحيوانات المهددة بالانقراض أو المحظور تداولها\n'
                  '🚫 الأدوية والمواد الطبية التي تستلزم وصفة طبية\n'
                  '🚫 السلع المقلدة أو المغشوشة\n'
                  '🚫 المعلومات الشخصية لأفراد آخرين\n'
                  '🚫 أي محتوى يخالف الأنظمة والقوانين السعودية',
            ),
            const SizedBox(height: 12),

            _buildSection(
              icon: Icons.verified_user_outlined,
              title: 'التزامات المُعلِن',
              color: const Color(0xFF7C3AED),
              content:
                  '• جميع المعلومات والصور المنشورة يجب أن تكون صحيحة ودقيقة.\n'
                  '• المُعلِن مسؤول قانونيًا عن محتوى إعلانه.\n'
                  '• يُحظر نشر إعلانات وهمية أو تضليلية.\n'
                  '• يجب أن يكون السعر المعروض رقمًا واضحًا ودقيقًا.\n'
                  '• المُعلِن يتحمل المسؤولية الكاملة عن صحة الصفقة.',
            ),
            const SizedBox(height: 12),

            _buildSection(
              icon: Icons.update_rounded,
              title: 'تحديث الإعلانات',
              color: const Color(0xFFF59E0B),
              content:
                  '• يمكن تحديث الإعلان (رفعه للأعلى) مرة واحدة كل 24 ساعة.\n'
                  '• الإعلانات النشطة تنتهي صلاحيتها بعد 30 يومًا من النشر.\n'
                  '• يحق للمنصة حذف أي إعلان يخالف شروط الاستخدام دون إشعار مسبق.',
            ),
            const SizedBox(height: 12),

            _buildSection(
              icon: Icons.assignment_return_outlined,
              title: 'الاسترجاع والاستبدال',
              color: const Color(0xFF0891B2),
              content:
                  'مؤسسة برق واضح لا تمارس نشاط البيع أو الشراء بل يقتصر نشاطها على التسويق الإلكتروني فقط، '
                  'حيث تمكن المستخدم من النشر ونشر اعلاناته وفق الضوابط والشروط المحددة في استخدام الموقع. '
                  'لذلك فإن اتفاقية البيع والشراء وخدمات ما بعد البيع وما يلحق بها من تبعات تقتصر مسئوليتها '
                  'على البائع والمشتري فقط.',
            ),
            const SizedBox(height: 12),

            _buildSection(
              icon: Icons.security_rounded,
              title: 'الأمان والاحتيال',
              color: const Color(0xFFEF4444),
              content:
                  '• في حال التعرض لعملية احتيال، يُرجى التواصل فورًا مع الجهات الأمنية المختصة '
                  '(الشرطة أو من خلال منصة أبشر).\n'
                  '• المنصة لا تطلب أبدًا بياناتك البنكية أو كلمات المرور.\n'
                  '• تحقق من هوية البائع قبل إتمام أي صفقة.',
            ),
            const SizedBox(height: 20),

            // Last updated
            Center(
              child: Text(
                'آخر تحديث: يوليو 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.neutralGray700,
              height: 1.7,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
