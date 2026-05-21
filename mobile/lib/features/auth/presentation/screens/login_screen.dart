import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState is AuthAuthenticated) {
      context.go('/');
    } else if (authState is AuthError) {
      _showError(authState.message);
      ref.read(authProvider.notifier).clearError();
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
    final loading = ref.watch(authProvider) is AuthLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'برق واضح',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تسجيل الدخول لحسابك',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.neutralGray500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Email / password form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'البريد غير صالح'
                            : null,
                        decoration: _inputDec(
                          hint: 'example@email.com',
                          prefix: const Icon(
                            Icons.email_outlined,
                            color: AppTheme.neutralGray500,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'مطلوب' : null,
                        decoration: _inputDec(
                          hint: '••••••••',
                          prefix: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.neutralGray500,
                            size: 20,
                          ),
                          suffix: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.neutralGray500,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AuthButton(
                        label: 'دخول',
                        loading: loading,
                        onTap: _login,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ليس لديك حساب؟  ',
                        style: TextStyle(
                          color: AppTheme.neutralGray500,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: const Text(
                          'إنشاء حساب',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

InputDecoration _inputDec({
  required String hint,
  Widget? prefix,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    hintTextDirection: TextDirection.ltr,
    prefixIcon: prefix != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: prefix,
          )
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: suffix,
          )
        : null,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: true,
    fillColor: Colors.white,
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

class _AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _AuthButton({
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
