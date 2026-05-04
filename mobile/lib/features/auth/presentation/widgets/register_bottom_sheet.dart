import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

const _kInputTextStyle = TextStyle(color: AppTheme.neutralGray900, fontSize: 15);

/// Shows the register bottom sheet. After successful registration [onSuccess] is called.
Future<void> showRegisterBottomSheet(
  BuildContext context, {
  required VoidCallback onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RegisterBottomSheet(onSuccess: onSuccess),
  );
}

class _RegisterBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _RegisterBottomSheet({required this.onSuccess});

  @override
  ConsumerState<_RegisterBottomSheet> createState() => _RegisterBottomSheetState();
}

class _RegisterBottomSheetState extends ConsumerState<_RegisterBottomSheet> {
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

  String _normalizePhone(String raw) {
    final t = raw.trim();
    if (t.startsWith('+966')) return t;
    if (t.startsWith('966'))  return '+$t';
    if (t.startsWith('05'))   return '+966${t.substring(1)}';
    if (t.startsWith('5'))    return '+966$t';
    return t;
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
    if (ref.read(authProvider) is AuthAuthenticated) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider) is AuthLoading;

    ref.listen(authProvider, (_, next) {
      if (next is AuthError) {
        _showError(next.message);
        ref.read(authProvider.notifier).clearError();
      }
    });

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ────────────────────────────────────────────────
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.neutralGray200,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Header ─────────────────────────────────────────────────────
                Center(
                  child: Column(children: [
                    SizedBox(
                      width: 80, height: 52,
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'إنشاء حساب جديد',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'انضم إلى آلاف البائعين والمشترين في برق واضح',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Name ───────────────────────────────────────────────────────
                _FieldLabel('الاسم الكامل', required: true),
                TextFormField(
                  controller: _nameCtrl,
                  textDirection: TextDirection.rtl,
                  style: _kInputTextStyle,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'الاسم يجب أن يكون حرفين على الأقل' : null,
                  decoration: _dec(hint: 'أحمد محمد', icon: Icons.person_outline_rounded),
                ),
                const SizedBox(height: 14),

                // ── Phone ──────────────────────────────────────────────────────
                _FieldLabel('رقم الجوال', required: true),
                TextFormField(
                  controller: _phoneCtrl,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.phone,
                  style: _kInputTextStyle,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                  validator: (v) {
                    final phone = _normalizePhone(v ?? '');
                    return RegExp(r'^\+9665[0-9]{8}$').hasMatch(phone)
                        ? null : 'رقم الجوال غير صالح (مثال: 0501234567)';
                  },
                  decoration: _dec(hint: '05xxxxxxxx', icon: Icons.phone_outlined),
                ),
                const SizedBox(height: 14),

                // ── Email (optional) ───────────────────────────────────────────
                _FieldLabel('البريد الإلكتروني', required: false),
                TextFormField(
                  controller: _emailCtrl,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.emailAddress,
                  style: _kInputTextStyle,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return v.contains('@') ? null : 'البريد غير صالح';
                  },
                  decoration: _dec(hint: 'you@example.com (اختياري)', icon: Icons.email_outlined),
                ),
                const SizedBox(height: 14),

                // ── Password ───────────────────────────────────────────────────
                _FieldLabel('كلمة المرور', required: true),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: _kInputTextStyle,
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Submit ─────────────────────────────────────────────────────
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
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                              )),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Back to login link ─────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('لديك حساب؟ تسجيل الدخول',
                      style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
