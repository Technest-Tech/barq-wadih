'use client';

import { useState, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useRouter, useParams } from 'next/navigation';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import {
  User, Mail, Lock, Eye, EyeOff,
  Loader2, AlertCircle, CheckCircle2, Shield, Phone,
} from 'lucide-react';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './page.module.css';

// ── Step 2 schema ─────────────────────────────────────────────────────────────
const detailsSchema = z.object({
  name:                  z.string().min(2, 'الاسم يجب أن يكون حرفين على الأقل'),
  email:                 z.string().email('البريد غير صالح').min(1, 'البريد الإلكتروني مطلوب'),
  password:              z.string().min(8, 'كلمة المرور 8 أحرف على الأقل'),
  password_confirmation: z.string(),
}).refine(d => d.password === d.password_confirmation, {
  message: 'كلمتا المرور غير متطابقتين',
  path: ['password_confirmation'],
});
type DetailsForm = z.infer<typeof detailsSchema>;

function getStrength(pass: string) {
  let score = 0;
  if (pass.length >= 8)           score++;
  if (/[A-Z]/.test(pass))         score++;
  if (/[0-9]/.test(pass))         score++;
  if (/[^A-Za-z0-9]/.test(pass))  score++;
  return score;
}

export default function RegisterPage() {
  const [step, setStep]           = useState<1 | 2>(1);

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  const [country, setCountry]     = useState<'SA' | 'EG'>('SA');
  const [phoneNum, setPhoneNum]   = useState('');
  const [phoneError, setPhoneError] = useState('');
  const [verifiedPhone, setVerifiedPhone] = useState('');

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  const [showPass, setShowPass]   = useState(false);
  const [error, setError]         = useState('');
  const [success, setSuccess]     = useState(false);

  const { setAuth } = useAuthStore();
  const router      = useRouter();
  const params      = useParams();
  const locale      = (params?.locale as string) || 'ar';

  const { register, handleSubmit, watch, formState: { errors, isSubmitting } } =
    useForm<DetailsForm>({ resolver: zodResolver(detailsSchema) });

  const watchPassword = watch('password', '');
  const strength      = useMemo(() => getStrength(watchPassword ?? ''), [watchPassword]);
  const strengthColor = ['#ef4444', '#f97316', '#eab308', '#22c55e'][strength - 1] ?? '#e5e7eb';
  const strengthWidth = `${(strength / 4) * 100}%`;

  // ── Phone helpers ──────────────────────────────────────────────────────────

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

  // ── Step 1: proceed without OTP ───────────────────────────────────────────

  const handlePhoneNext = () => {
    if (!isValidPhone(phoneNum)) {
      setPhoneError(country === 'SA'
        ? 'أدخل رقم سعودي صحيح (مثال: 0512345678)'
        : 'أدخل رقم مصري صحيح (مثال: 01012345678)');
      return;
    }
    setPhoneError('');
    setVerifiedPhone(normalizePhone(phoneNum));
    setStep(2);
  };

  // ── Step 2: register ───────────────────────────────────────────────────────

  const onSubmit = async (data: DetailsForm) => {
    setError('');
    try {
      const res = await authApi.register({
        name:                  data.name,
        phone:                 verifiedPhone,
        email:                 data.email,
        password:              data.password,
        password_confirmation: data.password_confirmation,
        locale:                'ar',
      });
      if (res.data) {
        setAuth(res.data.user, res.data.token);
        setSuccess(true);
        setTimeout(() => router.replace(`/${locale}`), 1400);
      }
    } catch (err) {
      if (err instanceof ApiClientError && err.errors) {
        setError(Object.values(err.errors).flat()[0] ?? err.message);
      } else {
        setError(err instanceof ApiClientError ? err.message : 'حدث خطأ. حاول مرة أخرى.');
      }
    }
  };

  return (
    <div className={styles.container}>

      <div className={styles.heading}>
        <h2 className={styles.title}>إنشاء حساب 🚀</h2>
        <p className={styles.subtitle}>انضم إلى آلاف البائعين والمشترين</p>
      </div>

      {/* Step indicator */}
      <div className={styles.stepRow}>
        <div className={styles.stepItem}>
          <div className={`${styles.stepCircle} ${step > 1 ? styles.stepDone : styles.stepActive}`}>
            {step > 1 ? <CheckCircle2 size={14} /> : '1'}
          </div>
          <span className={`${styles.stepLabel} ${styles.stepLabelActive}`}>رقم الجوال</span>
        </div>
        <div className={`${styles.stepConnector} ${step > 1 ? styles.stepConnectorDone : ''}`} />
        <div className={styles.stepItem}>
          <div className={`${styles.stepCircle} ${step === 2 ? styles.stepActive : ''}`}>{'2'}</div>
          <span className={`${styles.stepLabel} ${step === 2 ? styles.stepLabelActive : ''}`}>البيانات</span>
        </div>
      </div>

      {/* Banners */}
      <AnimatePresence>
        {error && (
          <motion.div className={styles.errorBanner}
            initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}>
            <AlertCircle size={16} /> {error}
          </motion.div>
        )}
        {success && (
          <motion.div className={styles.successBanner}
            initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }}>
            <CheckCircle2 size={16} /> تم إنشاء حسابك! جاري التحويل...
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Step 1: Phone ── */}
      {step === 1 && (
        <div className={styles.fieldGroup}>
          <div className={styles.field}>
            <label className={styles.label}>
              رقم الجوال <span className={styles.badgeRequired}>مطلوب</span>
            </label>
            <div className={styles.phoneWrap}>
              <button
                type="button"
                className={styles.phonePrefixBtn}
                onClick={() => { setCountry(c => c === 'SA' ? 'EG' : 'SA'); setPhoneNum(''); setPhoneError(''); }}
                title="اضغط لتغيير الدولة"
              >
                <span className={styles.phoneFlag}>{country === 'SA' ? '🇸🇦' : '🇪🇬'}</span>
                <span>{country === 'SA' ? '+966' : '+20'}</span>
              </button>
              <input
                className={`${styles.phoneInput} ${phoneError ? styles.inputError : ''}`}
                type="tel"
                inputMode="numeric"
                placeholder={country === 'SA' ? '5XXXXXXXX' : '10XXXXXXXXX'}
                maxLength={country === 'SA' ? 9 : 10}
                value={phoneNum}
                onChange={e => { setPhoneNum(e.target.value.replace(/\D/g, '')); setPhoneError(''); }}
                onKeyDown={e => e.key === 'Enter' && handlePhoneNext()}
              />
            </div>
            {phoneError && <span className={styles.fieldError}>{phoneError}</span>}
          </div>

          <button className={styles.btnPrimary} onClick={handlePhoneNext}>
            <Phone size={16} /> التالي
          </button>

          <p className={styles.footer}>
            لديك حساب؟{' '}
            <Link href="login" className={styles.footerLink}>تسجيل الدخول</Link>
          </p>
        </div>
      )}

      {/* ── Step 2: Details ── */}
      {step === 2 && (
        <form onSubmit={handleSubmit(onSubmit)} noValidate>
          <div className={styles.fieldGroup}>

            <div className={styles.verifiedBadge}>
              <CheckCircle2 size={15} /> {verifiedPhone}
            </div>

            <div className={styles.field}>
              <label className={styles.label}>الاسم الكامل <span className={styles.badgeRequired}>مطلوب</span></label>
              <div className={styles.inputWrap}>
                <User size={17} className={styles.inputIcon} />
                <input
                  className={`${styles.input} ${errors.name ? styles.inputError : ''}`}
                  type="text" placeholder="أحمد محمد"
                  {...register('name')}
                />
              </div>
              {errors.name && <span className={styles.fieldError}>{errors.name.message}</span>}
            </div>

            <div className={styles.field}>
              <label className={styles.label}>البريد الإلكتروني <span className={styles.badgeRequired}>مطلوب</span></label>
              <div className={styles.inputWrap}>
                <Mail size={17} className={styles.inputIconLtr} />
                <input
                  className={`${styles.input} ${styles.inputLtr} ${errors.email ? styles.inputError : ''}`}
                  type="email" placeholder="you@example.com"
                  {...register('email')}
                />
              </div>
              {errors.email && <span className={styles.fieldError}>{errors.email.message}</span>}
            </div>

            <div className={styles.field}>
              <label className={styles.label}>كلمة المرور <span className={styles.badgeRequired}>مطلوب</span></label>
              <div className={styles.inputWrap}>
                <Lock size={17} className={styles.inputIconLtr} />
                <input
                  className={`${styles.input} ${styles.inputLtr} ${errors.password ? styles.inputError : ''}`}
                  type={showPass ? 'text' : 'password'}
                  placeholder="٨ أحرف على الأقل"
                  style={{ paddingLeft: '44px', paddingRight: '44px' }}
                  {...register('password')}
                />
                <button type="button" className={styles.eyeBtn} onClick={() => setShowPass(p => !p)}>
                  {showPass ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {watchPassword && watchPassword.length > 0 && (
                <div className={styles.strengthBar}>
                  <div className={styles.strengthFill} style={{ width: strengthWidth, background: strengthColor }} />
                </div>
              )}
              {errors.password && <span className={styles.fieldError}>{errors.password.message}</span>}
            </div>

            <div className={styles.field}>
              <label className={styles.label}>تأكيد كلمة المرور</label>
              <div className={styles.inputWrap}>
                <Shield size={17} className={styles.inputIconLtr} />
                <input
                  className={`${styles.input} ${styles.inputLtr} ${errors.password_confirmation ? styles.inputError : ''}`}
                  type={showPass ? 'text' : 'password'}
                  placeholder="••••••••"
                  style={{ paddingLeft: '44px' }}
                  {...register('password_confirmation')}
                />
              </div>
              {errors.password_confirmation && (
                <span className={styles.fieldError}>{errors.password_confirmation.message}</span>
              )}
            </div>

            <button className={styles.btnPrimary} type="submit" disabled={isSubmitting || success}>
              {isSubmitting
                ? <Loader2 size={18} className={styles.spinner} />
                : success
                  ? <><CheckCircle2 size={18} /> تم إنشاء الحساب!</>
                  : 'إنشاء الحساب'}
            </button>

            <button type="button" className={styles.btnGhost}
              onClick={() => { setStep(1); setError(''); }}>
              ← تغيير رقم الجوال
            </button>
          </div>
        </form>
      )}

      {step === 2 && (
        <p className={styles.terms}>
          بإنشاء حساب، أنت توافق على{' '}
          <a href="#" className={styles.termsLink}>الشروط والأحكام</a>
          {' '}و{' '}
          <a href="#" className={styles.termsLink}>سياسة الخصوصية</a>
        </p>
      )}
    </div>
  );
}
