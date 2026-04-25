'use client';

import { useState, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import {
  User, Mail, Lock, Eye, EyeOff,
  Loader2, AlertCircle, CheckCircle2, Shield,
} from 'lucide-react';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './page.module.css';

// ── Schema ────────────────────────────────────────────────────────────────────
const schema = z.object({
  name:                  z.string().min(2, 'الاسم يجب أن يكون حرفين على الأقل'),
  phone:                 z.string().min(9, 'أدخل 9 أرقام').max(9, 'أدخل 9 أرقام').regex(/^[0-9]+$/, 'أرقام فقط'),
  email:                 z.union([z.string().email('البريد غير صالح'), z.literal('')]).optional(),
  password:              z.string().min(8, 'كلمة المرور 8 أحرف على الأقل'),
  password_confirmation: z.string(),
}).refine(d => d.password === d.password_confirmation, {
  message: 'كلمتا المرور غير متطابقتين',
  path: ['password_confirmation'],
});
type RegisterForm = z.infer<typeof schema>;

// Password strength helper
function getStrength(pass: string) {
  let score = 0;
  if (pass.length >= 8)  score++;
  if (/[A-Z]/.test(pass)) score++;
  if (/[0-9]/.test(pass)) score++;
  if (/[^A-Za-z0-9]/.test(pass)) score++;
  return score;
}

export default function RegisterPage() {
  const [showPass, setShowPass]   = useState(false);
  const [error, setError]         = useState('');
  const [success, setSuccess]     = useState(false);
  const { setAuth }               = useAuthStore();
  const router                    = useRouter();

  const { register, handleSubmit, watch, formState: { errors, isSubmitting } } =
    useForm<RegisterForm>({ resolver: zodResolver(schema), defaultValues: { email: '' } });

  const watchPassword = watch('password', '');
  const strength = useMemo(() => getStrength(watchPassword ?? ''), [watchPassword]);
  const strengthColor = ['#ef4444', '#f97316', '#eab308', '#22c55e'][strength - 1] ?? '#e5e7eb';
  const strengthWidth = `${(strength / 4) * 100}%`;

  const onSubmit = async (data: RegisterForm) => {
    setError('');
    try {
      const res = await authApi.register({
        name:                  data.name,
        phone:                 '+966' + data.phone,
        email:                 data.email || undefined,
        password:              data.password,
        password_confirmation: data.password_confirmation,
        locale:                'ar',
      });
      if (res.data) {
        setAuth(res.data.user, res.data.token);
        setSuccess(true);
        setTimeout(() => router.push('/'), 1400);
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

      {/* ── Heading ── */}
      <div className={styles.heading}>
        <h2 className={styles.title}>إنشاء حساب 🚀</h2>
        <p className={styles.subtitle}>انضم إلى آلاف البائعين والمشترين</p>
      </div>

      {/* ── Banners ── */}
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

      <form onSubmit={handleSubmit(onSubmit)} noValidate>
        <div className={styles.fieldGroup}>

          {/* Name */}
          <div className={styles.field}>
            <label className={styles.label}>
              الاسم الكامل
              <span className={styles.badgeRequired}>مطلوب</span>
            </label>
            <div className={styles.inputWrap}>
              <User size={17} className={styles.inputIcon} />
              <input
                className={`${styles.input} ${errors.name ? styles.inputError : ''}`}
                type="text"
                placeholder="أحمد محمد"
                {...register('name')}
              />
            </div>
            {errors.name && <span className={styles.fieldError}>{errors.name.message}</span>}
          </div>

          {/* Phone */}
          <div className={styles.field}>
            <label className={styles.label}>
              رقم الجوال
              <span className={styles.badgeRequired}>مطلوب</span>
            </label>
            <div className={`${styles.phoneWrap} ${errors.phone ? styles.inputError : ''}`}>
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
                {...register('phone')}
              />
            </div>
            {errors.phone && <span className={styles.fieldError}>{errors.phone.message}</span>}
          </div>

          {/* Email */}
          <div className={styles.field}>
            <label className={styles.label}>
              البريد الإلكتروني
              <span className={styles.badgeOptional}>اختياري</span>
            </label>
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

          {/* Password */}
          <div className={styles.field}>
            <label className={styles.label}>
              كلمة المرور
              <span className={styles.badgeRequired}>مطلوب</span>
            </label>
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
            {/* Password strength bar */}
            {watchPassword && watchPassword.length > 0 && (
              <div className={styles.strengthBar}>
                <div className={styles.strengthFill} style={{ width: strengthWidth, background: strengthColor }} />
              </div>
            )}
            {errors.password && <span className={styles.fieldError}>{errors.password.message}</span>}
          </div>

          {/* Confirm Password */}
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
        </div>
      </form>

      <p className={styles.terms}>
        بإنشاء حساب، أنت توافق على{' '}
        <a href="#" className={styles.termsLink}>الشروط والأحكام</a>
        {' '}و{' '}
        <a href="#" className={styles.termsLink}>سياسة الخصوصية</a>
      </p>

      <p className={styles.footer}>
        لديك حساب؟{' '}
        <Link href="login" className={styles.footerLink}>تسجيل الدخول</Link>
      </p>
    </div>
  );
}
