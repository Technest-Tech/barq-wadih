'use client';

import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useRouter, useParams } from 'next/navigation';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Phone, Mail, Lock, Eye, EyeOff,
  Loader2, AlertCircle, ArrowLeft, CheckCircle2,
} from 'lucide-react';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './page.module.css';

// ── Schemas ───────────────────────────────────────────────────────────────────
const emailSchema = z.object({
  email:    z.string().min(1, 'البريد مطلوب').email('البريد غير صالح'),
  password: z.string().min(1, 'كلمة المرور مطلوبة'),
});
type EmailForm = z.infer<typeof emailSchema>;

type Tab = 'phone' | 'email';

// Animation variants
const tabVariants = {
  enter: (dir: number) => ({ opacity: 0, x: dir * 24 }),
  center: { opacity: 1, x: 0 },
  exit:  (dir: number) => ({ opacity: 0, x: dir * -24 }),
};

export default function LoginPage() {
  const [tab, setTab]             = useState<Tab>('phone');
  const [tabDir, setTabDir]       = useState(1);
  const [showPass, setShowPass]   = useState(false);
  const [error, setError]         = useState('');
  const [loading, setLoading]     = useState(false);

  // Phone OTP state
  const [phoneNum, setPhoneNum]   = useState('');
  const [otpSent, setOtpSent]     = useState(false);
  const [otpCode, setOtpCode]     = useState('');
  const [otpSuccess, setOtpSuccess] = useState(false);

  const { setAuth, isAuthenticated, _hasHydrated } = useAuthStore();
  const router = useRouter();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';

  // Redirect already-authenticated users away from the login page (wait for hydration)
  useEffect(() => {
    if (!_hasHydrated) return;
    if (isAuthenticated) router.replace(`/${locale}`);
  }, [_hasHydrated, isAuthenticated, locale, router]);

  const switchTab = (next: Tab) => {
    setTabDir(next === 'phone' ? -1 : 1);
    setTab(next);
    setError('');
  };

  // ── Email form ──────────────────────────────────────────────────────────────
  const { register, handleSubmit, formState: { errors, isSubmitting } } =
    useForm<EmailForm>({ resolver: zodResolver(emailSchema) });

  const onEmailSubmit = async (data: EmailForm) => {
    setError('');
    try {
      const res = await authApi.login(data);
      if (res.data) {
        setAuth(res.data.user, res.data.token);
        router.replace(`/${locale}`);
      }
    } catch (err) {
      setError(err instanceof ApiClientError ? err.message : 'حدث خطأ. حاول مرة أخرى.');
    }
  };

  // ── Phone OTP ───────────────────────────────────────────────────────────────
  const handleSendOtp = async () => {
    const full = '+966' + phoneNum.replace(/^0/, '');
    if (!/^\+966[0-9]{9}$/.test(full)) {
      setError('أدخل رقم جوال سعودي صحيح (9 أرقام)');
      return;
    }
    setError('');
    setLoading(true);
    // Firebase integration goes here
    setTimeout(() => { setLoading(false); setOtpSent(true); }, 800);
  };

  const handleVerifyOtp = () => {
    if (otpCode.length !== 6) { setError('أدخل الرمز المكوّن من 6 أرقام'); return; }
    setOtpSuccess(true);
    setError('خاصية OTP تتطلب ربط مشروع Firebase.');
  };

  return (
    <div className={styles.container}>

      {/* ── Heading ── */}
      <div className={styles.heading}>
        <h2 className={styles.title}>مرحباً بك 👋</h2>
        <p className={styles.subtitle}>سجّل دخولك للمتابعة</p>
      </div>

      {/* ── Error banner ── */}
      <AnimatePresence>
        {error && (
          <motion.div
            className={styles.errorBanner}
            initial={{ opacity: 0, y: -8, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, scale: 0.97 }}
            transition={{ duration: 0.2 }}
          >
            <AlertCircle size={16} /> {error}
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Tab switcher ── */}
      <div className={styles.tabRow}>
        <button
          className={`${styles.tab} ${tab === 'phone' ? styles.tabActive : ''}`}
          onClick={() => switchTab('phone')}
        >
          <Phone size={15} /> رقم الجوال
        </button>
        <button
          className={`${styles.tab} ${tab === 'email' ? styles.tabActive : ''}`}
          onClick={() => switchTab('email')}
        >
          <Mail size={15} /> البريد الإلكتروني
        </button>
      </div>

      {/* ── Tab content ── */}
      <AnimatePresence mode="wait" custom={tabDir}>
        {tab === 'phone' && (
          <motion.div
            key="phone-tab"
            custom={tabDir}
            variants={tabVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.22, ease: 'easeOut' }}
          >
            {!otpSent ? (
              /* Step 1: Enter phone */
              <div className={styles.fieldGroup}>
                <div className={styles.field}>
                  <label className={styles.label}>رقم الجوال</label>
                  <div className={styles.phoneWrap}>
                    <div className={styles.phonePrefix}>
                      <span className={styles.phoneFlag}>🇸🇦</span>
                      <span>+966</span>
                    </div>
                    <input
                      className={styles.phoneInput}
                      type="tel"
                      inputMode="numeric"
                      placeholder="5XXXXXXXX"
                      maxLength={9}
                      value={phoneNum}
                      onChange={e => setPhoneNum(e.target.value.replace(/\D/g, ''))}
                    />
                  </div>
                </div>
                <button
                  className={styles.btnPrimary}
                  onClick={handleSendOtp}
                  disabled={loading}
                >
                  {loading
                    ? <Loader2 size={18} className={styles.spinner} />
                    : 'إرسال رمز التحقق'}
                </button>
              </div>
            ) : (
              /* Step 2: Enter OTP */
              <div className={styles.fieldGroup}>
                <p className={styles.otpHint}>
                  تم إرسال رمز لـ +966{phoneNum} ← تحقق من رسائلك
                </p>
                <input
                  className={styles.otpInput}
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  placeholder="------"
                  value={otpCode}
                  onChange={e => setOtpCode(e.target.value.replace(/\D/g, ''))}
                  autoFocus
                />
                <button className={styles.btnPrimary} onClick={handleVerifyOtp} disabled={loading}>
                  {loading ? <Loader2 size={18} className={styles.spinner} /> : 'تحقق وادخل'}
                </button>
                <button className={styles.btnGhost} onClick={() => { setOtpSent(false); setOtpCode(''); }}>
                  <ArrowLeft size={14} style={{ marginLeft: 4 }} /> تغيير الرقم
                </button>
              </div>
            )}
          </motion.div>
        )}

        {tab === 'email' && (
          <motion.div
            key="email-tab"
            custom={tabDir}
            variants={tabVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.22, ease: 'easeOut' }}
          >
            <form onSubmit={handleSubmit(onEmailSubmit)} noValidate>
              <div className={styles.fieldGroup}>
                <div className={styles.field}>
                  <label className={styles.label}>البريد الإلكتروني</label>
                  <div className={styles.inputWrap}>
                    <Mail size={17} className={styles.inputIconLtr} />
                    <input
                      className={`${styles.input} ${styles.inputLtr} ${errors.email ? styles.inputError : ''}`}
                      type="email"
                      placeholder="you@example.com"
                      {...register('email')}
                    />
                  </div>
                  {errors.email && <span className={styles.fieldError}>{errors.email.message}</span>}
                </div>

                <div className={styles.field}>
                  <label className={styles.label}>كلمة المرور</label>
                  <div className={styles.inputWrap}>
                    <Lock size={17} className={styles.inputIconLtr} />
                    <input
                      className={`${styles.input} ${styles.inputLtr} ${errors.password ? styles.inputError : ''}`}
                      type={showPass ? 'text' : 'password'}
                      placeholder="••••••••"
                      style={{ paddingLeft: '44px', paddingRight: '44px' }}
                      {...register('password')}
                    />
                    <button
                      type="button"
                      className={styles.eyeBtn}
                      onClick={() => setShowPass(p => !p)}
                    >
                      {showPass ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                  {errors.password && <span className={styles.fieldError}>{errors.password.message}</span>}
                </div>

                <button
                  className={styles.btnPrimary}
                  type="submit"
                  disabled={isSubmitting}
                >
                  {isSubmitting
                    ? <Loader2 size={18} className={styles.spinner} />
                    : 'دخول'}
                </button>
              </div>
            </form>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Footer ── */}
      <p className={styles.footer}>
        ليس لديك حساب؟{' '}
        <Link href="register" className={styles.footerLink}>إنشاء حساب مجاني</Link>
      </p>
    </div>
  );
}
