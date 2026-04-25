import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── Phone OTP state ────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  bool _otpSent       = false;
  bool _phoneBusy     = false;
  bool _otpBusy       = false;
  String? _verificationId;
  int? _resendToken;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  // ── Email state ────────────────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _obscure       = true;

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

  // ── Phone helpers ──────────────────────────────────────────────────────────

  /// Normalise: 05XXXXXXXX → +96605XXXXXXXX, or pass through +966...
  String _normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+966')) return trimmed;
    if (trimmed.startsWith('966'))  return '+$trimmed';
    if (trimmed.startsWith('05'))   return '+966$trimmed';
    if (trimmed.startsWith('5'))    return '+9665$trimmed';
    return trimmed;
  }

  bool _isValidPhone(String phone) =>
      RegExp(r'^\+9665[0-9]{8}$').hasMatch(_normalizePhone(phone));

  void _startResendCountdown() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 0) { t.cancel(); }
      if (mounted) setState(() => _resendCountdown--);
    });
  }

  // ── Send OTP ───────────────────────────────────────────────────────────────

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

      // ── Auto-retrieval (Android only) ──────────────────────────────────────
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-fills — sign in immediately
        await _signInWithCredential(credential);
      },

      // ── OTP sent ───────────────────────────────────────────────────────────
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId  = verificationId;
          _resendToken     = resendToken;
          _otpSent         = true;
          _phoneBusy       = false;
        });
        _startResendCountdown();
      },

      // ── Timeout ────────────────────────────────────────────────────────────
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        setState(() => _verificationId = verificationId);
      },

      // ── Error ─────────────────────────────────────────────────────────────
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

  // ── Verify OTP ─────────────────────────────────────────────────────────────

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
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await _signInWithCredential(credential);
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

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken  = await userCred.user?.getIdToken();
      if (idToken == null) throw Exception('لم يتم الحصول على رمز التحقق');

      await ref.read(authProvider.notifier).loginWithFirebase(
        idToken: idToken,
        name: null, // name collected on first launch profile screen if is_new
      );

      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState is AuthAuthenticated) context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() { _otpBusy = false; _phoneBusy = false; });
      _showError(e.toString().contains('ApiException')
          ? 'خطأ في الخادم. حاول مرة أخرى.'
          : 'فشل تسجيل الدخول. حاول مرة أخرى.');
    }
  }

  // ── Email login ────────────────────────────────────────────────────────────

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ref.read(authProvider) is AuthAuthenticated) context.go('/');
  }

  // ── Error snackbar ─────────────────────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen for API-level errors from authProvider
    ref.listen(authProvider, (_, next) {
      if (next is AuthError) {
        _showError(next.message);
        ref.read(authProvider.notifier).clearError();
      }
    });

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

                // ── Header ───────────────────────────────────────────────────
                Center(
                  child: Column(children: [
                    Container(
                      width: 120, height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('برق واضح',
                      style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('تسجيل الدخول لحسابك',
                      style: TextStyle(fontSize: 14, color: AppTheme.neutralGray500),
                    ),
                  ]),
                ),

                const SizedBox(height: 32),

                // ── Tab bar ──────────────────────────────────────────────────
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

                const SizedBox(height: 28),

                // ── Tab content ──────────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: SizedBox(
                    height: _otpSent ? 280 : 220,
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        // ── Phone OTP tab ─────────────────────────────────
                        _PhoneOtpTab(
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
                        ),

                        // ── Email tab ─────────────────────────────────────
                        _EmailTab(
                          formKey:     _formKey,
                          emailCtrl:   _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          obscure:     _obscure,
                          loading:     ref.watch(authProvider) is AuthLoading,
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                          onLogin:     _loginEmail,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const _Divider(),
                const SizedBox(height: 20),

                // ── Register link ────────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ليس لديك حساب؟  ',
                        style: TextStyle(color: AppTheme.neutralGray500, fontSize: 14)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
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

// ── Phone OTP Tab ─────────────────────────────────────────────────────────────

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
          // Phone input
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            style: const TextStyle(fontSize: 16, letterSpacing: 1),
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
          _AuthButton(
            label: 'إرسال رمز التحقق',
            loading: phoneBusy,
            onTap: onSendOtp,
          ),
        ],
      );
    }

    // OTP entry state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تم إرسال الرمز إلى ${phoneCtrl.text}',
          style: const TextStyle(fontSize: 13, color: AppTheme.neutralGray600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // 6-digit OTP field
        TextField(
          controller: otpCtrl,
          textAlign: TextAlign.center,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 14,
            color: AppTheme.primaryBlue,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '------',
            hintStyle: TextStyle(
              fontSize: 28, letterSpacing: 14,
              color: AppTheme.neutralGray200,
              fontWeight: FontWeight.w800,
            ),
            filled: true,
            fillColor: AppTheme.neutralGray50,
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
        _AuthButton(
          label: 'تحقق وادخل',
          loading: otpBusy,
          onTap: onVerifyOtp,
        ),
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

// ── Email Tab ─────────────────────────────────────────────────────────────────

class _EmailTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passwordCtrl;
  final bool obscure, loading;
  final VoidCallback onToggleObscure, onLogin;

  const _EmailTab({
    required this.formKey, required this.emailCtrl, required this.passwordCtrl,
    required this.obscure, required this.loading,
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
            validator: (v) => (v == null || !v.contains('@')) ? 'البريد غير صالح' : null,
            decoration: _inputDec(hint: 'example@email.com',
              prefix: const Icon(Icons.email_outlined, color: AppTheme.neutralGray500, size: 20)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
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
          const SizedBox(height: 20),
          _AuthButton(label: 'دخول', loading: loading, onTap: onLogin),
        ],
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
    prefixIcon: prefix != null ? Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: prefix,
    ) : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix != null ? Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: suffix,
    ) : null,
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
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(color: AppTheme.neutralGray200)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('أو', style: TextStyle(fontSize: 13, color: AppTheme.neutralGray500)),
      ),
      Expanded(child: Divider(color: AppTheme.neutralGray200)),
    ]);
  }
}
