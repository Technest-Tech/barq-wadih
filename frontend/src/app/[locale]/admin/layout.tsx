'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams, usePathname } from 'next/navigation';
import AdminSidebar from '@/components/admin/AdminSidebar/AdminSidebar';
import AdminHeader from '@/components/admin/AdminHeader/AdminHeader';
import { useAuthStore } from '@/store/auth.store';
import { authApi } from '@/lib/api/auth';
import { ApiClientError } from '@/lib';
import styles from './admin-layout.module.css';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [checked, setChecked] = useState(false);

  const router = useRouter();
  const params = useParams();
  const pathname = usePathname();
  const locale = (params?.locale as string) || 'ar';

  const { user, token, isAuthenticated, setAuth, clearAuth } = useAuthStore();

  const isLoginPage = pathname?.endsWith('/admin/login');

  useEffect(() => {
    if (isLoginPage) { setChecked(true); return; }

    const verify = async () => {
      // Fast path: store already has a valid admin user
      if (isAuthenticated && token && (user?.role === 'admin' || user?.role === 'super_admin')) {
        setChecked(true);
        return;
      }

      // No token at all → send to login
      const storedToken = token ?? (typeof window !== 'undefined' ? localStorage.getItem('auth_token') : null);
      if (!storedToken) {
        router.replace(`/${locale}/admin/login`);
        return;
      }

      // Token exists but store is empty (e.g. hard refresh) → verify with /me
      try {
        const res = await authApi.me();
        const u = res.data;
        if (!u || (u.role !== 'admin' && u.role !== 'super_admin')) {
          clearAuth();
          router.replace(`/${locale}/admin/login`);
          return;
        }
        setAuth(u, storedToken);
        setChecked(true);
      } catch (err) {
        clearAuth();
        if (err instanceof ApiClientError && err.status === 401) {
          router.replace(`/${locale}/admin/login`);
        } else {
          router.replace(`/${locale}/admin/login`);
        }
      }
    };

    verify();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoginPage]);

  // Listen for global 401 events fired by the API client
  useEffect(() => {
    const handler = () => {
      clearAuth();
      router.replace(`/${locale}/admin/login`);
    };
    window.addEventListener('auth:unauthorized', handler);
    return () => window.removeEventListener('auth:unauthorized', handler);
  }, [clearAuth, router, locale]);

  // Login page: no chrome, no guard
  if (isLoginPage) {
    return <>{children}</>;
  }

  // Waiting for verification
  if (!checked) {
    return (
      <div className={styles.loadingOverlay}>
        <div className={styles.loadingSpinner}>
          <div className={styles.spinner} />
          <span>جاري التحقق من الصلاحيات...</span>
        </div>
      </div>
    );
  }

  // Checked but not admin (edge case, router.replace already called)
  if (!isAuthenticated || (user?.role !== 'admin' && user?.role !== 'super_admin')) {
    return (
      <div className={styles.accessDenied}>
        <h1>⛔ غير مصرح</h1>
        <p>ليس لديك صلاحيات للوصول إلى لوحة الإدارة.</p>
        <a href={`/${locale}`} className={styles.backLink}>العودة للرئيسية</a>
      </div>
    );
  }

  const roleLabel = user?.role === 'super_admin' ? 'مشرف عام' : 'مشرف';

  return (
    <div className={`${styles.adminLayout} ${collapsed ? styles.collapsed : ''}`}>
      <AdminSidebar
        collapsed={collapsed}
        mobileOpen={mobileOpen}
        onToggleCollapse={() => setCollapsed(!collapsed)}
        onCloseMobile={() => setMobileOpen(false)}
        adminName={user?.name}
        adminRole={roleLabel}
      />

      <AdminHeader
        onToggleMobile={() => setMobileOpen(!mobileOpen)}
        adminName={user?.name}
        adminRole={roleLabel}
      />

      {mobileOpen && (
        <div className={styles.mobileOverlay} onClick={() => setMobileOpen(false)} />
      )}

      <main className={styles.adminMain}>
        {children}
      </main>
    </div>
  );
}
