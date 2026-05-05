import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Shows the auth bottom sheet. After successful login, [onSuccess] is called.
Future<void> showAuthBottomSheet(
  BuildContext context, {
  required VoidCallback onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuthBottomSheet(onSuccess: onSuccess),
  );
}

class _AuthBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _AuthBottomSheet({required this.onSuccess});

  @override
  ConsumerState<_AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<_AuthBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── Phone OTP state ─────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  bool _otpSent        = false;
  bool _phoneBusy      = false;
  bool _otpBusy        = false;
  String? _verificationId;
  int? _resendToken;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  // ── Email state ─────────────────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _obscure       = true;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Phone helpers ────────────────────────────────────────────────────────────

  String _normalizePhone(String raw) {
    final t = raw.trim();
    if (t.startsWith('+966')) return t;
    if (t.startsWith('966'))  return '+$t';
    if (t.startsWith('05'))   return '+966${t.substring(1)}';
    if (t.startsWith('5'))    return '+966$t';
    return t;
  }

  bool _isValidPhone(String p) =>
      RegExp(r'^\+9665[0-9]{8}$').hasMatch(_normalizePhone(p));

  void _startResendCountdown() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 0) t.cancel();
      if (mounted) setState(() => _resendCountdown--);
    });
  }

  // ── Send OTP ─────────────────────────────────────────────────────────────────

  Future<void> _sendOtp({bool resend = false}) async {
    final phone = _normalizePhone(_phoneCtrl.text);
    if (!_isValidPhone(_phoneCtrl.text)) {
      _showError('أدخل رقم جوال سعودي صحيح (مثال: 0501234567)');
      return;
    }
    setState(() => _phoneBusy = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _signInWithCredential(cred);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken    = resendToken;
          _otpSent        = true;
          _phoneBusy      = false;
        });
        _startResendCountdown();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        setState(() => _verificationId = verificationId);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _phoneBusy = false);
        final msg = switch (e.code) {
          'invalid-phone-number'   => 'رقم الجوال غير صالح',
          'too-many-requests'      => 'تم تجاوز الحد المسموح. حاول لاحقاً',
          'quota-exceeded'         => 'تم استنفاد الحصة المجانية مؤقتاً',
          'network-request-failed' => 'تحقق من اتصالك بالإنترنت',
          _                        => e.message ?? 'حدث خطأ في الإرسال',
        };
        _showError(msg);
      },
    );
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) {
      _showError('أدخل رمز التحقق المكون من 6 أرقام');
      return;
    }
    if (_verificationId == null) {
      _showError('انتهت صلاحية الرمز. أعد الإرسال');
      return;
    }
    setState(() => _otpBusy = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await _signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      setState(() => _otpBusy = false);
      final msg = switch (e.code) {
        'invalid-verification-code' => 'رمز التحقق غير صحيح',
        'session-expired'           => 'انتهت صلاحية الجلسة. أعد إرسال الرمز',
        _                           => e.message ?? 'خطأ في التحقق',
      };
      _showError(msg);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential cred) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final idToken  = await userCred.user?.getIdToken();
      if (idToken == null) throw Exception('لم يتم الحصول على رمز التحقق');

      await ref.read(authProvider.notifier).loginWithFirebase(
        idToken: idToken,
        name: null,
      );

      if (!mounted) return;
      if (ref.read(authProvider) is AuthAuthenticated) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _otpBusy = false; _phoneBusy = false; });
      _showError(e.toString().contains('ApiException')
          ? 'خطأ في الخادم. حاول مرة أخرى.'
          : 'فشل تسجيل الدخول. حاول مرة أخرى.');
    }
  }

  // ── Email login ───────────────────────────────────────────────────────────────

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _emailError = null);
    await ref.read(authProvider.notifier).login(
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState is AuthAuthenticated) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else if (authState is AuthError) {
      setState(() => _emailError = authState.message);
      ref.read(authProvider.notifier).clearError();
    }
  }

  // ── Error snackbar ────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────────────
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
              const SizedBox(height: 24),

              // ── Header ───────────────────────────────────────────────────────
              Center(
                child: Column(children: [
                  SizedBox(
                    width: 80, height: 52,
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سجّل دخولك للوصول إلى هذه الميزة',
                    style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Tab bar ──────────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.neutralGray600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(text: 'رقم الجوال'),
                    Tab(text: 'البريد الإلكتروني'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Tab content ──────────────────────────────────────────────────
              ListenableBuilder(
                listenable: _tab,
                builder: (context, _) => _tab.index == 0
                    ? _PhoneOtpTab(
                        phoneCtrl:       _phoneCtrl,
                        otpCtrl:         _otpCtrl,
                        otpSent:         _otpSent,
                        phoneBusy:       _phoneBusy,
                        otpBusy:         _otpBusy,
                        resendCountdown: _resendCountdown,
                        onSendOtp:       () => _sendOtp(),
                        onVerifyOtp:     _verifyOtp,
                        onResend:        () => _sendOtp(resend: true),
                        onChangePhone:   () => setState(() {
                          _otpSent = false;
                          _otpCtrl.clear();
                          _resendTimer?.cancel();
                        }),
                      )
                    : _EmailTab(
                        formKey:         _formKey,
                        emailCtrl:       _emailCtrl,
                        passwordCtrl:    _passwordCtrl,
                        obscure:         _obscure,
                        loading:         ref.watch(authProvider) is AuthLoading,
                        errorMessage:    _emailError,
                        onToggleObscure: () => setState(() => _obscure = !_obscure),
                        onLogin:         _loginEmail,
                      ),
              ),

              const SizedBox(height: 20),

              // ── Divider ──────────────────────────────────────────────────────
              Row(children: [
                Expanded(child: Divider(color: AppTheme.neutralGray200)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('أو', style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500)),
                ),
                Expanded(child: Divider(color: AppTheme.neutralGray200)),
              ]),

              const SizedBox(height: 16),

              // ── Register link ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ليس لديك حساب؟  ',
                    style: TextStyle(color: AppTheme.neutralGray500, fontSize: 14)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/register');
                    },
                    child: const Text('إنشاء حساب',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _kInputTextStyle = TextStyle(color: AppTheme.neutralGray900, fontSize: 15);

// ── Phone OTP Tab ──────────────────────────────────────────────────────────────

class _PhoneOtpTab extends StatelessWidget {
  final TextEditingController phoneCtrl, otpCtrl;
  final bool otpSent, phoneBusy, otpBusy;
  final int resendCountdown;
  final VoidCallback onSendOtp, onVerifyOtp, onResend, onChangePhone;

  const _PhoneOtpTab({
    required this.phoneCtrl, required this.otpCtrl,
    required this.otpSent, required this.phoneBusy, required this.otpBusy,
    required this.resendCountdown,
    required this.onSendOtp, required this.onVerifyOtp,
    required this.onResend, required this.onChangePhone,
  });

  @override
  Widget build(BuildContext context) {
    if (!otpSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            style: const TextStyle(fontSize: 16, letterSpacing: 1, color: AppTheme.neutralGray900),
            decoration: _inputDec(
              hint: '05xxxxxxxx',
              prefix: Container(
                margin: const EdgeInsets.only(left: 12),
                child: const Text('🇸🇦', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('سيتم إرسال رمز تحقق SMS إلى رقمك',
            style: TextStyle(fontSize: 12, color: AppTheme.neutralGray500)),
          const SizedBox(height: 20),
          _AuthButton(label: 'إرسال رمز التحقق', loading: phoneBusy, onTap: onSendOtp),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تم إرسال الرمز إلى ${phoneCtrl.text}',
          style: const TextStyle(fontSize: 13, color: AppTheme.neutralGray600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: otpCtrl,
          textAlign: TextAlign.center,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800,
            letterSpacing: 14, color: AppTheme.primaryBlue, decorationColor: AppTheme.primaryBlue,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: TextStyle(
              fontSize: 28, letterSpacing: 14,
              color: AppTheme.neutralGray200, fontWeight: FontWeight.w800,
            ),
            filled: true, fillColor: AppTheme.neutralGray50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.neutralGray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.neutralGray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AuthButton(label: 'تحقق وادخل', loading: otpBusy, onTap: onVerifyOtp),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (resendCountdown > 0)
              Text('إعادة الإرسال بعد $resendCountdown ث',
                style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500))
            else
              TextButton(
                onPressed: onResend,
                child: const Text('إعادة إرسال الرمز',
                  style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: onChangePhone,
              child: Text('تغيير الرقم',
                style: TextStyle(color: AppTheme.neutralGray500, fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Email Tab ──────────────────────────────────────────────────────────────────

class _EmailTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passwordCtrl;
  final bool obscure, loading;
  final String? errorMessage;
  final VoidCallback onToggleObscure, onLogin;

  const _EmailTab({
    required this.formKey, required this.emailCtrl, required this.passwordCtrl,
    required this.obscure, required this.loading,
    this.errorMessage,
    required this.onToggleObscure, required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            style: _kInputTextStyle,
            validator: (v) => (v == null || !v.contains('@')) ? 'البريد غير صالح' : null,
            decoration: _inputDec(
              hint: 'example@email.com',
              prefix: const Icon(Icons.email_outlined, color: AppTheme.neutralGray500, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
            style: _kInputTextStyle,
            validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            decoration: _inputDec(
              hint: '••••••••',
              prefix: const Icon(Icons.lock_outline_rounded, color: AppTheme.neutralGray500, size: 20),
              suffix: GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.neutralGray500, size: 20,
                ),
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _AuthButton(label: 'دخول', loading: loading, onTap: onLogin),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

InputDecoration _inputDec({required String hint, Widget? prefix, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    hintTextDirection: TextDirection.ltr,
    prefixIcon: prefix != null
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix)
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix != null
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: suffix)
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
  const _AuthButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
              : Text(label,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                  )),
        ),
      ),
    );
  }
}
