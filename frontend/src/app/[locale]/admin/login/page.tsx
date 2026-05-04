'use client';

import { useState, FormEvent, useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import Image from 'next/image';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import { useAuthStore } from '@/store/auth.store';
import styles from './login.module.css';

export default function AdminLoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';
  const { setAuth, user, isAuthenticated } = useAuthStore();

  useEffect(() => {
    if (isAuthenticated && (user?.role === 'admin' || user?.role === 'super_admin')) {
      router.replace(`/${locale}/admin`);
    }
  }, [isAuthenticated, user, locale, router]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await authApi.login({ email, password });
      const data = res.data;
      if (!data?.token) {
        setError('لم يتم استلام رمز الدخول');
        return;
      }
      if (data.user.role !== 'admin' && data.user.role !== 'super_admin') {
        setError('ليس لديك صلاحيات المشرف');
        return;
      }
      setAuth(data.user, data.token);
      router.replace(`/${locale}/admin`);
    } catch (err) {
      if (err instanceof ApiClientError) {
        setError(err.message || 'بيانات الدخول غير صحيحة');
      } else {
        setError('خطأ في الاتصال بالخادم');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <div className={styles.logo}>
          <Image
            src="/images/logo_nobg.png"
            alt="برق واضح"
            width={110}
            height={110}
            className={styles.logoImage}
            priority
          />
          <div className={styles.logoDivider} />
          <p className={styles.logoSub}>لوحة الإدارة</p>
        </div>

        <form className={styles.form} onSubmit={handleSubmit}>
          {error && (
            <div className={styles.error}>
              <span>⚠️</span>
              <span>{error}</span>
            </div>
          )}

          <div className={styles.field}>
            <label className={styles.label} htmlFor="admin-email">البريد الإلكتروني</label>
            <div className={styles.inputWrapper}>
              <span className={styles.inputIcon}>✉</span>
              <input
                id="admin-email"
                className={styles.input}
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@barqwadih.com"
                required
                disabled={loading}
                autoComplete="email"
              />
            </div>
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="admin-password">كلمة المرور</label>
            <div className={styles.inputWrapper}>
              <span className={styles.inputIcon}>🔒</span>
              <input
                id="admin-password"
                className={styles.input}
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                disabled={loading}
                autoComplete="current-password"
              />
            </div>
          </div>

          <button className={styles.submitBtn} type="submit" disabled={loading}>
            {loading ? (
              <>
                <span className={styles.btnSpinner} />
                جاري الدخول...
              </>
            ) : (
              'تسجيل الدخول'
            )}
          </button>
        </form>

        <a href={`/${locale}`} className={styles.backLink}>
          <span>←</span>
          <span>العودة للموقع الرئيسي</span>
        </a>
      </div>
    </div>
  );
}
