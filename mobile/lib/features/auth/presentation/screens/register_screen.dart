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
  // ── Step: 1=phone, 2=details ───────────────────────────────────────────────
  int _step = 1;

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  final _phoneCtrl   = TextEditingController();
  String? _phoneError;
  String  _verifiedPhone = '';

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _obscure      = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Phone helpers ──────────────────────────────────────────────────────────

  String _normalizePhone(String raw) {
    final t = raw.trim();
    if (t.startsWith('+966')) return t;
    if (t.startsWith('966'))  return '+$t';
    if (t.startsWith('05'))   return '+966${t.substring(1)}';
    if (t.startsWith('5') && t.length == 9) return '+966$t';
    if (t.startsWith('+20'))  return t;
    if (t.startsWith('010') || t.startsWith('011') ||
        t.startsWith('012') || t.startsWith('015')) { return '+2$t'; }
    return t;
  }

  bool _isValidPhone(String phone) {
    final n = _normalizePhone(phone);
    return RegExp(r'^\+9665[0-9]{8}$').hasMatch(n) ||
           RegExp(r'^\+20(10|11|12|15)[0-9]{8}$').hasMatch(n);
  }

  void _handlePhoneNext() {
    if (!_isValidPhone(_phoneCtrl.text)) {
      setState(() => _phoneError = 'أدخل رقم جوال صحيح (مثال: 0501234567 أو 01012345678)');
      return;
    }
    setState(() {
      _phoneError    = null;
      _verifiedPhone = _normalizePhone(_phoneCtrl.text);
      _step          = 2;
    });
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
      name:     _nameCtrl.text.trim(),
      phone:    _verifiedPhone,
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ref.read(authProvider) is AuthAuthenticated) context.go('/');
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
    final auth    = ref.watch(authProvider);
    final loading = auth is AuthLoading;

    ref.listen(authProvider, (_, next) {
      if (next is AuthError) {
        _showError(next.message);
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
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Image.asset('assets/images/logo.png', height: 60, fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                _StepIndicator(current: _step),
                const SizedBox(height: 28),
                if (_step == 1) _buildPhoneStep(),
                if (_step == 2) _buildDetailsStep(loading),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Phone ──────────────────────────────────────────────────────────

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('أدخل رقم جوالك',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.neutralGray900)),
        const SizedBox(height: 6),
        Text('سيتم ربط هذا الرقم بحسابك',
          style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500, height: 1.4)),
        const SizedBox(height: 24),
        _FieldLabel('رقم الجوال', required: true),
        TextFormField(
          controller: _phoneCtrl,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          onFieldSubmitted: (_) => _handlePhoneNext(),
          decoration: _dec(hint: '05xxxxxxxx أو 010xxxxxxxx', icon: Icons.phone_outlined).copyWith(
            errorText: _phoneError,
          ),
          onChanged: (_) { if (_phoneError != null) setState(() => _phoneError = null); },
        ),
        const SizedBox(height: 24),
        _ActionButton(label: 'التالي', loading: false, onTap: _handlePhoneNext),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('لديك حساب؟ تسجيل الدخول',
              style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Details ────────────────────────────────────────────────────────

  Widget _buildDetailsStep(bool loading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أكمل بياناتك',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.neutralGray900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 16),
              const SizedBox(width: 8),
              Text(_verifiedPhone,
                style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 24),

          _FieldLabel('الاسم الكامل', required: true),
          TextFormField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'الاسم يجب أن يكون حرفين على الأقل' : null,
            decoration: _dec(hint: 'أحمد محمد', icon: Icons.person_outline_rounded),
          ),
          const SizedBox(height: 16),

          _FieldLabel('البريد الإلكتروني', required: true),
          TextFormField(
            controller: _emailCtrl,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
              return v.contains('@') ? null : 'البريد غير صالح';
            },
            decoration: _dec(hint: 'you@example.com', icon: Icons.email_outlined),
          ),
          const SizedBox(height: 16),

          _FieldLabel('كلمة المرور', required: true),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            validator: (v) => (v == null || v.length < 8)
                ? 'كلمة المرور 8 أحرف على الأقل' : null,
            decoration: InputDecoration(
              hintText: '••••••••',
              filled: true, fillColor: Colors.white,
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.neutralGray500, size: 20),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.neutralGray200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.neutralGray200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
            ),
          ),
          const SizedBox(height: 28),

          _ActionButton(label: 'إنشاء الحساب', loading: loading, onTap: _submit),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('لديك حساب؟ تسجيل الدخول',
                style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _circle(1, current, 'رقم الجوال'),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 20),
            color: current > 1 ? AppTheme.primaryBlue : AppTheme.neutralGray200,
          ),
        ),
        _circle(2, current, 'البيانات'),
      ],
    );
  }

  Widget _circle(int step, int current, String label) {
    final done   = step < current;
    final active = step == current;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? AppTheme.primaryBlue : AppTheme.neutralGray100,
            border: Border.all(
              color: done || active ? AppTheme.primaryBlue : AppTheme.neutralGray200,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text('$step',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppTheme.neutralGray400,
                    )),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
          style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: done || active ? AppTheme.primaryBlue : AppTheme.neutralGray400,
          )),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

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

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, height: 50,
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
              : Text(label,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

InputDecoration _dec({required String hint, required IconData icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    filled: true, fillColor: Colors.white,
    prefixIcon: Icon(icon, color: AppTheme.neutralGray500, size: 20),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.neutralGray200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.neutralGray200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red)),
  );
}
