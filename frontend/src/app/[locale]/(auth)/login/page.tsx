'use client';

import { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useRouter, useParams } from 'next/navigation';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, Lock, Eye, EyeOff, Loader2, AlertCircle } from 'lucide-react';
import { useState } from 'react';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './page.module.css';

const emailSchema = z.object({
  email: z.string().min(1, 'البريد مطلوب').email('البريد غير صالح'),
  password: z.string().min(1, 'كلمة المرور مطلوبة'),
});
type EmailForm = z.infer<typeof emailSchema>;

export default function LoginPage() {
  const [showPass, setShowPass] = useState(false);
  const [error, setError] = useState('');

  const { setAuth, isAuthenticated, _hasHydrated } = useAuthStore();
  const router = useRouter();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';

  useEffect(() => {
    if (!_hasHydrated) return;
    if (isAuthenticated) router.replace(`/${locale}`);
  }, [_hasHydrated, isAuthenticated, locale, router]);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<EmailForm>({ resolver: zodResolver(emailSchema) });

  const onSubmit = async (data: EmailForm) => {
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

  return (
    <div className={styles.container}>
      <div className={styles.heading}>
        <h2 className={styles.title}>مرحباً بك 👋</h2>
        <p className={styles.subtitle}>سجّل دخولك للمتابعة</p>
      </div>

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

      <form onSubmit={handleSubmit(onSubmit)} noValidate>
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
                onClick={() => setShowPass((p) => !p)}
              >
                {showPass ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {errors.password && (
              <span className={styles.fieldError}>{errors.password.message}</span>
            )}
          </div>

          <button className={styles.btnPrimary} type="submit" disabled={isSubmitting}>
            {isSubmitting ? <Loader2 size={18} className={styles.spinner} /> : 'دخول'}
          </button>
        </div>
      </form>

      <p className={styles.footer}>
        ليس لديك حساب؟{' '}
        <Link href="register" className={styles.footerLink}>
          إنشاء حساب مجاني
        </Link>
      </p>
    </div>
  );
}
