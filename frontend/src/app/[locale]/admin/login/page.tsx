'use client';

import { useState, FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import styles from './login.module.css';

export default function AdminLoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000/api';
      const res = await fetch(`${BASE_URL}/v1/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      const json = await res.json();

      if (!res.ok) {
        setError(json.message || 'بيانات الدخول غير صحيحة');
        setLoading(false);
        return;
      }

      const user = json.data?.user || json.data;
      const token = json.data?.token;

      if (!token) {
        setError('لم يتم استلام رمز الدخول');
        setLoading(false);
        return;
      }

      // Check admin role
      if (user.role !== 'admin' && user.role !== 'super_admin') {
        setError('⛔ ليس لديك صلاحيات المشرف');
        setLoading(false);
        return;
      }

      // Store token and redirect
      localStorage.setItem('auth_token', token);
      localStorage.setItem('admin_user', JSON.stringify(user));
      router.push('/admin');
    } catch {
      setError('خطأ في الاتصال بالخادم');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <div className={styles.logo}>
          <div className={styles.logoIcon}>⚡</div>
          <h1 className={styles.logoTitle}>برق واضح</h1>
          <p className={styles.logoSub}>دخول لوحة الإدارة</p>
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

          <div className={styles.field}>
            <label className={styles.label} htmlFor="admin-password">كلمة المرور</label>
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

        <a href="/" className={styles.backLink}>← العودة للموقع الرئيسي</a>
      </div>
    </div>
  );
}
