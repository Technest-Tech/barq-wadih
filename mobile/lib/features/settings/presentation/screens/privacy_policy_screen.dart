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
            'آخر تحديث: أغسطس 2026',
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
      'البيانات التي نجمعها',
      'نجمع الاسم والبريد الإلكتروني اللازمين لإنشاء الحساب. رقم الجوال اختياري ما لم تختر تسجيل الدخول أو التحقق عبر الجوال. وقد تضيف اختيارياً صورة الملف والغلاف والنبذة والمنطقة والمدينة. عند نشر إعلان نجمع التفاصيل والصور وبيانات التواصل التي تختار إظهارها، والموقع الدقيق فقط بعد موافقتك. كما نعالج الرسائل النصية والصور والتسجيلات الصوتية التي ترسلها في المحادثات، وعمليات البحث والمفضلة والمتابعة والبلاغات والحظر، ومعرّف الحساب والجهاز ورمز الإشعارات ومعلومات تشخيصية أساسية.',
    ),
    (
      'استخدام المعلومات',
      'نستخدم البيانات لإنشاء الحساب وتسجيل الدخول، ونشر الإعلانات وعرض القريب منها، وتشغيل المحادثات والإشعارات، وتقديم الدعم، ومنع الاحتيال وإساءة الاستخدام، ومعالجة إثباتات التحويل والعمولات بعد إتمام بيع سلعة أو خدمة، وتحسين موثوقية التطبيق. لا نبيع بياناتك ولا نستخدمها للإعلانات الموجّهة عبر تطبيقات أو مواقع أخرى.',
    ),
    (
      'مشاركة المعلومات',
      'نعالج بعض البيانات لدى مزودي الخدمة الضروريين لتشغيل المنصة، ومنهم Google Firebase للمصادقة والمحادثات والإشعارات، ومزودو الاستضافة والتخزين والخرائط. قد تظهر بيانات الإعلان ومعلومات التواصل التي تختار نشرها لمستخدمي المنصة. وقد نفصح عن معلومات بالقدر المطلوب قانوناً أو لحماية المستخدمين وحقوقهم. لا نخزن بيانات بطاقات دفع؛ الدفع المتاح حالياً تحويل بنكي مع إمكانية إرفاق صورة الإيصال.',
    ),
    (
      'أمان البيانات',
      'نستخدم اتصالاً مشفراً وضوابط وصول وصلاحيات تحد من الوصول إلى البيانات. لا يوجد نظام إلكتروني آمن بشكل مطلق، لذلك نراجع وسائل الحماية ونحدّثها بصورة مستمرة.',
    ),
    (
      'حقوق المستخدم',
      'يمكنك الاطلاع على بيانات ملفك وتصحيحها، وإدارة ظهور رقمك وموقع الإعلان، وسحب أذونات الموقع والكاميرا والصور والميكروفون والإشعارات من إعدادات الجهاز. ويمكنك حذف الحساب والبيانات من الملف الشخصي عبر «حذف الحساب والبيانات نهائياً».',
    ),
    (
      'الاحتفاظ والحذف',
      'عند حذف الحساب نلغي الوصول ونحذف بيانات تسجيل الدخول والملف العام والإعلانات وصورها والمحادثات ووسائطها. قد نحتفظ بسجلات محدودة للمعاملات والمدفوعات وبلاغات السلامة ومكافحة الاحتيال فقط للمدة التي يفرضها النظام أو اللازمة لحماية المستخدمين، وتكون مفصولة عن الملف العام ولا تصلح لتسجيل الدخول.',
    ),
    (
      'أذونات الجهاز',
      'نطلب الكاميرا أو مكتبة الصور عندما تختار إضافة صورة، والميكروفون عندما تسجل رسالة صوتية، والموقع عندما تختار تحديد موقع إعلان أو عرض نتائج قريبة، والإشعارات عندما تختار استلام التنبيهات. يمكنك استخدام الوظائف الأخرى دون منح أذونات غير لازمة لها.',
    ),
    (
      'التواصل معنا',
      'إذا كانت لديك أي أسئلة أو مخاوف بشأن سياسة الخصوصية هذه، يمكنك التواصل مع فريق الدعم عبر البريد الإلكتروني: support@barqwadih.com أو الاتصال بنا عبر الأرقام المتاحة في صفحة "اتصل بنا".',
    ),
  ];
}
