import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'سياسة الخصوصية',
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
            _buildHeader(),
            const SizedBox(height: 16),
            for (final section in _sections) ...[
              _buildSection(section.$1, section.$2),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Icon(Icons.policy_rounded, color: Colors.white, size: 42),
          SizedBox(height: 10),
          Text(
            'سياسة الخصوصية',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'آخر تحديث: يناير 2025',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
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
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.neutralGray700,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  static const _sections = <(String, String)>[
    (
      'جمع المعلومات',
      'نقوم بجمع المعلومات التي تقدمها لنا مباشرةً عند إنشاء حساب أو نشر إعلان أو التواصل معنا. تشمل هذه المعلومات: الاسم، رقم الجوال، البريد الإلكتروني، وصور الإعلانات. كما نجمع معلومات تلقائياً عند استخدامك للتطبيق مثل بيانات الجهاز ونوع المتصفح.',
    ),
    (
      'استخدام المعلومات',
      'نستخدم المعلومات التي نجمعها لتشغيل التطبيق وتحسينه، ومعالجة معاملاتك، والتواصل معك بشأن خدماتنا، وتخصيص تجربتك، وضمان أمان المنصة. لن نبيع بياناتك الشخصية لأي طرف ثالث.',
    ),
    (
      'مشاركة المعلومات',
      'قد نشارك معلوماتك مع مزودي الخدمات الذين يساعدوننا في تشغيل التطبيق كمعالجي الدفع ومزودي خدمات التخزين السحابي. تلتزم هذه الأطراف بالحفاظ على سرية بياناتك. وقد نُفصح عن معلوماتك إذا اقتضى ذلك القانون أو حماية حقوقنا.',
    ),
    (
      'أمان البيانات',
      'نتخذ تدابير أمنية تقنية وتنظيمية مناسبة لحماية بياناتك من الوصول غير المصرح به أو الكشف أو التعديل أو الإتلاف. يُخزَّن رمز المصادقة بصورة مشفرة على جهازك ولا يمكن الوصول إليه من قِبل التطبيقات الأخرى.',
    ),
    (
      'حقوق المستخدم',
      'يحق لك الوصول إلى بياناتك الشخصية وتصحيحها أو حذفها في أي وقت من خلال إعدادات الحساب. كما يحق لك الاعتراض على معالجتها لأغراض تسويقية عبر التواصل مع فريق الدعم.',
    ),
    (
      'ملفات تعريف الارتباط',
      'نستخدم تقنيات مماثلة لملفات تعريف الارتباط لتخصيص تجربتك وتحليل استخدام التطبيق. يمكنك التحكم في هذه الإعدادات من خلال إعدادات جهازك، غير أن تعطيل بعضها قد يؤثر على وظائف التطبيق.',
    ),
    (
      'التواصل معنا',
      'إذا كانت لديك أي أسئلة أو مخاوف بشأن سياسة الخصوصية هذه، يمكنك التواصل مع فريق الدعم عبر البريد الإلكتروني: support@barqwadih.com أو الاتصال بنا عبر الأرقام المتاحة في صفحة "اتصل بنا".',
    ),
  ];
}
