'use client';

import { useState, useEffect, useRef } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { motion, AnimatePresence, type Variants } from 'framer-motion';
import { Phone, Mail, Lock, Eye, EyeOff, Loader2, AlertCircle, ArrowLeft, X } from 'lucide-react';
import { signInWithPhoneNumber, RecaptchaVerifier, type ConfirmationResult } from 'firebase/auth';
import { firebaseAuth } from '@/lib/firebase/auth';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './AuthModal.module.css';

// ── Schemas ───────────────────────────────────────────────────────────────────
const emailSchema = z.object({
  email:    z.string().min(1, 'البريد مطلوب').email('البريد غير صالح'),
  password: z.string().min(1, 'كلمة المرور مطلوبة'),
});
type EmailForm = z.infer<typeof emailSchema>;

type Tab = 'phone' | 'email';

const bgVariants: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1 }
};

const modalVariants: Variants = {
  hidden: { opacity: 0, scale: 0.95, y: 20 },
  visible: { opacity: 1, scale: 1, y: 0, transition: { type: 'spring', damping: 25, stiffness: 300 } },
  exit: { opacity: 0, scale: 0.95, y: -20, transition: { duration: 0.2 } }
};

const tabVariants: Variants = {
  enter: (dir: number) => ({ opacity: 0, x: dir * 24 }),
  center: { opacity: 1, x: 0 },
  exit:  (dir: number) => ({ opacity: 0, x: dir * -24 }),
};

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

export default function AuthModal({ isOpen, onClose, onSuccess }: AuthModalProps) {
  const [tab, setTab]             = useState<Tab>('phone');
  const [tabDir, setTabDir]       = useState(1);
  const [showPass, setShowPass]   = useState(false);
  const [error, setError]         = useState('');
  const [loading, setLoading]     = useState(false);

  // Phone OTP state
  const [phoneNum, setPhoneNum]       = useState('');
  const [otpSent, setOtpSent]         = useState(false);
  const [otpCode, setOtpCode]         = useState('');
  const [country, setCountry]         = useState<'SA' | 'EG'>('SA');
  const recaptchaRef  = useRef<RecaptchaVerifier | null>(null);
  const confirmRef    = useRef<ConfirmationResult | null>(null);

  const { setAuth } = useAuthStore();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';

  // Reset state when opened/closed
  useEffect(() => {
    if (isOpen) {
      setTab('phone');
      setError('');
      setLoading(false);
      setOtpSent(false);
      setPhoneNum('');
      setOtpCode('');
      confirmRef.current = null;
    } else {
      recaptchaRef.current?.clear();
      recaptchaRef.current = null;
    }
  }, [isOpen]);

  const switchTab = (next: Tab) => {
    setTabDir(next === 'phone' ? -1 : 1);
    setTab(next);
    setError('');
  };

  const { register, handleSubmit, formState: { errors, isSubmitting } } =
    useForm<EmailForm>({ resolver: zodResolver(emailSchema) });

  const onEmailSubmit = async (data: EmailForm) => {
    setError('');
    try {
      const res = await authApi.login(data);
      if (res.data) {
        setAuth(res.data.user, res.data.token);
        onSuccess?.();
        onClose();
      }
    } catch (err) {
      setError(err instanceof ApiClientError ? err.message : 'حدث خطأ. حاول مرة أخرى.');
    }
  };

  const normalizePhone = (raw: string) => {
    const t = raw.trim();
    if (country === 'SA') {
      if (t.startsWith('+966')) return t;
      if (t.startsWith('0'))    return '+966' + t.slice(1);
      return '+966' + t;
    } else {
      if (t.startsWith('+20')) return t;
      if (t.startsWith('0'))   return '+2' + t;
      return '+20' + t;
    }
  };

  const isValidPhone = (raw: string) => {
    const n = normalizePhone(raw);
    return /^\+9665\d{8}$/.test(n) || /^\+20(10|11|12|15)\d{8}$/.test(n);
  };

  const handleSendOtp = async () => {
    if (!isValidPhone(phoneNum)) {
      setError(country === 'SA'
        ? 'أدخل رقم سعودي صحيح (مثال: 0512345678)'
        : 'أدخل رقم مصري صحيح (مثال: 01012345678)');
      return;
    }
    setError('');
    setLoading(true);
    try {
      // Clear any previous verifier
      recaptchaRef.current?.clear();
      recaptchaRef.current = new RecaptchaVerifier(firebaseAuth, 'recaptcha-container', { size: 'invisible' });
      confirmRef.current = await signInWithPhoneNumber(firebaseAuth, normalizePhone(phoneNum), recaptchaRef.current);
      setOtpSent(true);
    } catch (e: unknown) {
      const code = (e as { code?: string }).code ?? '';
      console.error('[OTP]', code, e);
      setError(
        code === 'auth/too-many-requests'      ? 'تم تجاوز الحد. حاول لاحقاً' :
        code === 'auth/invalid-phone-number'   ? 'رقم الجوال غير صالح' :
        code === 'auth/quota-exceeded'         ? 'تم استنفاد الحصة. حاول لاحقاً' :
        code === 'auth/operation-not-allowed'  ? 'تسجيل الدخول بالهاتف غير مفعّل في Firebase' :
        code === 'auth/unauthorized-domain'    ? 'النطاق غير مصرح به في Firebase' :
        code === 'auth/captcha-check-failed'   ? 'فشل التحقق من reCAPTCHA. أعد المحاولة' :
        code === 'auth/billing-not-enabled'    ? 'يتطلب إرسال SMS ترقية خطة Firebase إلى Blaze' :
        `فشل إرسال الرمز (${code || 'unknown'})`
      );
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async () => {
    if (otpCode.length !== 6) { setError('أدخل الرمز المكوّن من 6 أرقام'); return; }
    if (!confirmRef.current)  { setError('انتهت الجلسة. أعد إرسال الرمز'); return; }
    setLoading(true);
    setError('');
    try {
      const result = await confirmRef.current.confirm(otpCode);
      const idToken = await result.user.getIdToken();
      const res = await authApi.firebase({ firebase_id_token: idToken, locale: 'ar' });
      if (res.data) {
        setAuth(res.data.user, res.data.token);
        onSuccess?.();
        onClose();
      }
    } catch (e: unknown) {
      const code = (e as { code?: string }).code ?? '';
      setError(
        code === 'auth/invalid-verification-code' ? 'رمز التحقق غير صحيح' :
        code === 'auth/code-expired'              ? 'انتهت صلاحية الرمز. أعد الإرسال' :
        'فشل التحقق. حاول مرة أخرى'
      );
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        className={styles.overlay}
        variants={bgVariants}
        initial="hidden"
        animate="visible"
        exit="hidden"
        onClick={onClose}
      >
        <motion.div
          className={styles.modal}
          variants={modalVariants}
          initial="hidden"
          animate="visible"
          exit="exit"
          onClick={e => e.stopPropagation()}
        >
          <button className={styles.closeBtn} onClick={onClose}>
            <X size={18} />
          </button>

          <div className={styles.header}>
            <h2 className={styles.title}>مرحباً بك 👋</h2>
            <p className={styles.subtitle}>سجّل دخولك للمتابعة</p>
          </div>

          {/* recaptcha-container must stay in DOM while phone tab is active */}
          <div id="recaptcha-container" style={{ display: 'none' }} />

          <div className={styles.body}>
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

            <div style={{ position: 'relative', minHeight: '180px' }}>
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
                    style={{ position: 'absolute', width: '100%' }}
                  >
                    {!otpSent ? (
                      <div className={styles.fieldGroup}>
                        <div className={styles.field}>
                          <label className={styles.label}>رقم الجوال</label>
                          <div className={styles.phoneWrap}>
                            <button
                              type="button"
                              className={styles.phonePrefixBtn}
                              onClick={() => { setCountry(c => c === 'SA' ? 'EG' : 'SA'); setPhoneNum(''); }}
                              title="اضغط لتغيير الدولة"
                            >
                              <span className={styles.phoneFlag}>{country === 'SA' ? '🇸🇦' : '🇪🇬'}</span>
                              <span>{country === 'SA' ? '+966' : '+20'}</span>
                            </button>
                            <input
                              className={styles.phoneInput}
                              type="tel"
                              inputMode="numeric"
                              placeholder={country === 'SA' ? '5XXXXXXXX' : '10XXXXXXXXX'}
                              maxLength={country === 'SA' ? 9 : 10}
                              value={phoneNum}
                              onChange={e => setPhoneNum(e.target.value.replace(/\D/g, ''))}
                            />
                          </div>
                        </div>
                        <button className={styles.btnPrimary} onClick={handleSendOtp} disabled={loading}>
                          {loading ? <Loader2 size={18} className={styles.spinner} /> : 'إرسال رمز التحقق'}
                        </button>
                      </div>
                    ) : (
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
                    style={{ position: 'absolute', width: '100%' }}
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

                        <button className={styles.btnPrimary} type="submit" disabled={isSubmitting}>
                          {isSubmitting ? <Loader2 size={18} className={styles.spinner} /> : 'دخول'}
                        </button>
                      </div>
                    </form>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>

          <p className={styles.footer}>
            ليس لديك حساب؟{' '}
            <Link href={`/${locale}/register`} className={styles.footerLink} onClick={onClose}>إنشاء حساب مجاني</Link>
          </p>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}
