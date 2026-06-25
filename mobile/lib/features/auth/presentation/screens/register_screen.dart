import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _buildPhone() {
    final digits = _phoneCtrl.text.trim();
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '+966$local';
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      _showError('يجب الموافقة على الشروط والأحكام للمتابعة');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .register(
          name: _nameCtrl.text.trim(),
          phone: _buildPhone(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (ref.read(authProvider) is AuthAuthenticated) {
      await _promptBiometricSetup();
      if (!mounted) return;
      context.go('/');
    }
  }

  /// After registration, offer to set up fingerprint login for next time.
  Future<void> _promptBiometricSetup() async {
    final supported = await ref.read(biometricSupportedProvider.future);
    if (!supported || !mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(
            Icons.fingerprint_rounded,
            color: AppTheme.primaryBlue,
            size: 44,
          ),
          title: const Text(
            'تفعيل الدخول بالبصمة',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: const Text(
            'هل تريد استخدام بصمتك لتسجيل الدخول بسرعة في المرة القادمة؟',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'لاحقًا',
                style: TextStyle(color: AppTheme.neutralGray500),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('تفعيل'),
            ),
          ],
        ),
      ),
    );

    if (enable != true || !mounted) return;

    final ok = await ref
        .read(authProvider.notifier)
        .setupBiometrics(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تفعيل الدخول بالبصمة'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.neutralGray900,
          ),
          onPressed: () => context.pop(),
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
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'إنشاء حساب جديد',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.neutralGray900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل بياناتك للتسجيل',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutralGray500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('الاسم الكامل', required: true),
                      TextFormField(
                        controller: _nameCtrl,
                        textDirection: TextDirection.rtl,
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'الاسم يجب أن يكون حرفين على الأقل'
                            : null,
                        decoration: _dec(
                          hint: 'أحمد محمد',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel('رقم الجوال', required: true),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'رقم الجوال مطلوب';
                            }
                            if (!RegExp(
                              r'^(05|5)[0-9]{8}$',
                            ).hasMatch(v.trim())) {
                              return 'أدخل رقم جوال سعودي صحيح (مثال: 0512345678)';
                            }
                            return null;
                          },
                          decoration: _phoneDec(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel('البريد الإلكتروني', required: true),
                      TextFormField(
                        controller: _emailCtrl,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'البريد الإلكتروني مطلوب';
                          return v.contains('@') ? null : 'البريد غير صالح';
                        },
                        decoration: _dec(
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel('كلمة المرور', required: true),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        validator: (v) => (v == null || v.length < 8)
                            ? 'كلمة المرور 8 أحرف على الأقل'
                            : null,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.neutralGray500,
                            size: 20,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.neutralGray500,
                                size: 20,
                              ),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.neutralGray200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.neutralGray200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryBlue,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Terms & conditions checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _acceptedTerms,
                              activeColor: AppTheme.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (v) =>
                                  setState(() => _acceptedTerms = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.neutralGray600,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: 'أوافق على '),
                                  TextSpan(
                                    text: 'الشروط والأحكام',
                                    style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => launchUrl(
                                        Uri.parse(
                                          'https://barqwadih.com/terms',
                                        ),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                  ),
                                  const TextSpan(text: ' و'),
                                  TextSpan(
                                    text: 'سياسة الخصوصية',
                                    style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => launchUrl(
                                        Uri.parse(
                                          'https://barqwadih.com/privacy',
                                        ),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _ActionButton(
                        label: 'إنشاء الحساب',
                        loading: loading,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          child: const Text(
                            'لديك حساب؟ تسجيل الدخول',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutralGray800,
          ),
          children: required
              ? [
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
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
  const _ActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                ),
          color: loading ? AppTheme.neutralGray200 : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: .25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

InputDecoration _phoneDec() {
  return InputDecoration(
    hintText: '05XXXXXXXX',
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    prefix: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🇸🇦', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        const Text(
          '+966',
          style: TextStyle(
            color: AppTheme.neutralGray700,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 18, color: AppTheme.neutralGray300),
        const SizedBox(width: 8),
      ],
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
  );
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
