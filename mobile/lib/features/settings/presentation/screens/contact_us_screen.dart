import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/riyal_text.dart';

// ── Static categories (hardcoded so FAQs always work without a network call) ──

class _FaqItem {
  final String q;
  final String a;
  const _FaqItem(this.q, this.a);
}

class _Category {
  final String slug;
  final String label;
  final List<_FaqItem> faqs;
  const _Category({
    required this.slug,
    required this.label,
    required this.faqs,
  });
}

const _kCategories = [
  _Category(
    slug: 'fees',
    label: 'العمولات وطرق الدفع',
    faqs: [
      _FaqItem(
        'ما هي طرق الدفع المتاحة؟',
        'الدفع المتاح حالياً هو التحويل البنكي، ثم إرفاق صورة الإيصال من داخل التطبيق لمراجعته.',
      ),
      _FaqItem(
        'هل توجد رسوم لنشر الإعلان؟',
        'لا. نشر الإعلان مجاني ولا يُطلب أي دفع قبل ظهوره.',
      ),
      _FaqItem(
        'متى تُدفع العمولة؟',
        'تُدفع بعد إتمام البيع: 99 ريالاً للسيارات، و10 ريالات للفئات الأخرى الخاضعة للعمولة، بينما الوظائف مجانية. يعرض التطبيق المبلغ بوضوح قبل نشر الإعلان.',
      ),
    ],
  ),
  _Category(
    slug: 'safety',
    label: 'السلامة والبلاغات',
    faqs: [
      _FaqItem(
        'كيف أبلّغ عن إعلان مخالف؟',
        'افتح الإعلان واضغط «إبلاغ»، ثم اختر السبب وأرسل البلاغ. يراجع فريقنا البلاغات ويتخذ الإجراء المناسب.',
      ),
      _FaqItem(
        'كيف أحظر مستخدماً؟',
        'افتح ملف المستخدم أو خيارات المحادثة واضغط «حظر». لن يتمكن المستخدم المحظور من التواصل معك.',
      ),
    ],
  ),
  _Category(
    slug: 'members',
    label: 'الأعضاء',
    faqs: [
      _FaqItem(
        'كيف أُفعّل حسابي؟',
        'يتم تفعيل الحساب تلقائياً عند التسجيل بالبريد الإلكتروني. رقم الجوال اختياري ويمكن استخدامه لتسجيل الدخول أو التحقق.',
      ),
      _FaqItem(
        'كيف أغيّر معلوماتي الشخصية؟',
        'من ملفك الشخصي اضغط على "تعديل الملف الشخصي" وقم بتحديث بياناتك ثم احفظ التغييرات.',
      ),
      _FaqItem(
        'كيف أحذف حسابي؟',
        'افتح ملفك الشخصي ثم اختر «حذف الحساب والبيانات نهائيًا». اكتب كلمة «حذف» للتأكيد؛ ستُحذف بيانات الدخول والملف العام والإعلانات فورًا، ولا يمكن التراجع.',
      ),
    ],
  ),
  _Category(
    slug: 'chat',
    label: 'المحادثات',
    faqs: [
      _FaqItem(
        'ماذا يمكنني إرساله في المحادثة؟',
        'يمكنك إرسال نصوص وصور ورسائل صوتية للتواصل بشأن الإعلان، مع الالتزام بقواعد الاستخدام.',
      ),
      _FaqItem(
        'كيف أوقف تواصل مستخدم؟',
        'يمكنك حظر المستخدم من خيارات المحادثة أو ملفه الشخصي.',
      ),
    ],
  ),
  _Category(
    slug: 'ads',
    label: 'الإعلانات (نشر - تعديل - حذف)',
    faqs: [
      _FaqItem(
        'كيف أنشر إعلاناً؟',
        'اضغط على زر "نشر إعلان" وأدخل التفاصيل المطلوبة ثم وافق على التعهد واضغط "نشر". النشر مجاني.',
      ),
      _FaqItem(
        'كيف أعدّل إعلاني؟',
        'من صفحة "إعلاناتي" اختر الإعلان المراد تعديله واضغط على "تعديل" وأجرِ التغييرات واحفظها.',
      ),
      _FaqItem(
        'كيف أحذف إعلاني؟',
        'من صفحة "إعلاناتي" اختر الإعلان واضغط على "حذف". تنبيه: لا يمكن التراجع عن الحذف.',
      ),
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  _Category? _selected;
  bool _showAll = false;
  bool _dropdownOpen = false;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ApiClient().dio.post(
        '/contact',
        data: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          'category': _selected?.slug,
          'message': _msgCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _msgCtrl.clear();
      setState(() {
        _selected = null;
        _submitting = false;
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم الإرسال', textAlign: TextAlign.center),
          content: const Text(
            'تم إرسال رسالتك بنجاح.\nسيتواصل معك فريق الدعم قريباً.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الإرسال، حاول مجدداً')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'تواصل معنا',
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
            // ── Main card ──────────────────────────────────────────────────
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  const Text(
                    'تواصل معنا',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2ECC71),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Custom dropdown ───────────────────────────────────────
                  _buildCustomDropdown(),

                  // ── FAQs for selected category ────────────────────────────
                  if (_selected != null) ...[
                    const SizedBox(height: 4),
                    for (final faq in _selected!.faqs)
                      _FaqTile(question: faq.q, answer: faq.a),
                  ],

                  const SizedBox(height: 16),

                  // ── Show all FAQs link ────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() {
                      _showAll = !_showAll;
                      if (_showAll) _selected = null;
                    }),
                    child: Text(
                      _showAll
                          ? 'إخفاء الأسئلة الشائعة'
                          : 'عرض جميع الأسئلة الشائعة',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryBlueLight,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.primaryBlueLight,
                      ),
                    ),
                  ),

                  // ── All FAQs expanded ─────────────────────────────────────
                  if (_showAll) ...[
                    const SizedBox(height: 16),
                    for (final cat in _kCategories) ...[
                      const SizedBox(height: 8),
                      Text(
                        cat.label,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      for (final faq in cat.faqs)
                        _FaqTile(question: faq.q, answer: faq.a),
                    ],
                  ],
                ],
              ),
            ),

            // ── Contact form ───────────────────────────────────────────────
            const SizedBox(height: 20),
            _buildContactForm(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Custom tap-to-expand dropdown (reliable on RTL) ───────────────────────

  Widget _buildCustomDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: _dropdownOpen
                    ? AppTheme.primaryBlue
                    : AppTheme.neutralGray300,
                width: _dropdownOpen ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: Radius.circular(_dropdownOpen ? 0 : 12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _dropdownOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.neutralGray600,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selected?.label ?? 'إختار السبب',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      color: _selected != null
                          ? AppTheme.neutralGray800
                          : AppTheme.neutralGray500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_dropdownOpen)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: AppTheme.neutralGray300),
                right: BorderSide(color: AppTheme.neutralGray300),
                bottom: BorderSide(color: AppTheme.neutralGray300),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final cat in _kCategories)
                  InkWell(
                    onTap: () => setState(() {
                      _selected = cat;
                      _dropdownOpen = false;
                      _showAll = false;
                    }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _selected?.slug == cat.slug
                            ? AppTheme.primaryBlue.withValues(alpha: .06)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: cat == _kCategories.last
                                ? Colors.transparent
                                : AppTheme.neutralGray200,
                          ),
                        ),
                      ),
                      child: Text(
                        cat.label,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selected?.slug == cat.slug
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selected?.slug == cat.slug
                              ? AppTheme.primaryBlue
                              : AppTheme.neutralGray800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Contact form ──────────────────────────────────────────────────────────

  Widget _buildContactForm() {
    return _buildCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'أرسل لنا رسالة',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutralGray800,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              _nameCtrl,
              'الاسم الكامل',
              Icons.person_outline,
              validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              _emailCtrl,
              'البريد الإلكتروني',
              Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                final e = (v ?? '').trim();
                if (e.isEmpty) return 'البريد الإلكتروني مطلوب';
                if (!e.contains('@')) return 'بريد إلكتروني غير صالح';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildField(
              _phoneCtrl,
              'رقم الجوال (اختياري)',
              Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _msgCtrl,
              maxLines: 5,
              textAlign: TextAlign.right,
              decoration: _inputDecoration(
                'اكتب رسالتك هنا...',
                Icons.message_outlined,
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'الرسالة مطلوبة';
                if (t.length < 10) return 'الرسالة قصيرة جداً';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إرسال الرسالة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      textAlign: TextAlign.right,
      decoration: _inputDecoration(hint, icon),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.neutralGray400, fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.neutralGray500, size: 20),
      filled: true,
      fillColor: AppTheme.neutralGray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.neutralGray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.neutralGray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

// ── FAQ accordion tile ────────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.question,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 12, start: 28),
            child: RiyalText(
              widget.answer,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.neutralGray700,
                height: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}
