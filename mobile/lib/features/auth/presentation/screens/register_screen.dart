import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
      name:     _nameCtrl.text.trim(),
      phone:    _normalizePhone(_phoneCtrl.text),
      email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ref.read(authProvider) is AuthAuthenticated) context.go('/');
  }

  String _normalizePhone(String raw) {
    final t = raw.trim();
    if (t.startsWith('+966')) return t;
    if (t.startsWith('05'))   return '+966$t';
    if (t.startsWith('5'))    return '+9665$t';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final auth    = ref.watch(authProvider);
    final loading = auth is AuthLoading;

    ref.listen(authProvider, (_, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(next.message, style: const TextStyle(color: Colors.white))),
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.neutralGray900),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('إنشاء حساب جديد',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: AppTheme.neutralGray900,
                    )),
                  const SizedBox(height: 6),
                  Text('انضم إلى آلاف البائعين والمشترين في برق واضح',
                    style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500, height: 1.4)),
                  const SizedBox(height: 28),

                  // ── Name ────────────────────────────────────────────────────
                  _FieldLabel('الاسم الكامل', required: true),
                  TextFormField(
                    controller: _nameCtrl,
                    textDirection: TextDirection.rtl,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'الاسم يجب أن يكون حرفين على الأقل' : null,
                    decoration: _dec(hint: 'أحمد محمد',
                      icon: Icons.person_outline_rounded),
                  ),
                  const SizedBox(height: 16),

                  // ── Phone ───────────────────────────────────────────────────
                  _FieldLabel('رقم الجوال', required: true),
                  TextFormField(
                    controller: _phoneCtrl,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                    validator: (v) {
                      final phone = _normalizePhone(v ?? '');
                      return RegExp(r'^\+9665[0-9]{8}$').hasMatch(phone)
                          ? null : 'رقم الجوال غير صالح (مثال: 0501234567)';
                    },
                    decoration: _dec(hint: '05xxxxxxxx',
                      icon: Icons.phone_outlined),
                  ),
                  const SizedBox(height: 16),

                  // ── Email ───────────────────────────────────────────────────
                  _FieldLabel('البريد الإلكتروني', required: false),
                  TextFormField(
                    controller: _emailCtrl,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return v.contains('@') ? null : 'البريد غير صالح';
                    },
                    decoration: _dec(hint: 'you@example.com (اختياري)',
                      icon: Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),

                  // ── Password ────────────────────────────────────────────────
                  _FieldLabel('كلمة المرور', required: true),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'كلمة المرور 8 أحرف على الأقل' : null,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.neutralGray500, size: 20),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.neutralGray500, size: 20,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Submit ───────────────────────────────────────────────────
                  GestureDetector(
                    onTap: loading ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: loading ? null : const LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                        ),
                        color: loading ? AppTheme.neutralGray200 : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: loading ? null : [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: .25),
                            blurRadius: 8, offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('إنشاء الحساب',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('لديك حساب؟ تسجيل الدخول',
                        style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {required this.required});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.neutralGray800),
          children: required
              ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
              : [],
        ),
      ),
    );
  }
}

InputDecoration _dec({required String hint, required IconData icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(icon, color: AppTheme.neutralGray500, size: 20),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}
