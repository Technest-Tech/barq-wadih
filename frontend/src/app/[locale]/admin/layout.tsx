'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import AdminSidebar from '@/components/admin/AdminSidebar/AdminSidebar';
import AdminHeader from '@/components/admin/AdminHeader/AdminHeader';
import styles from './admin-layout.module.css';

interface AdminUser {
  id: number;
  name: string;
  role: string;
  role_label: string;
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [authState, setAuthState] = useState<'loading' | 'ok' | 'denied' | 'unauthenticated'>('loading');
  const [adminUser, setAdminUser] = useState<AdminUser | null>(null);
  const router = useRouter();

  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('auth_token');

      if (!token) {
        setAuthState('unauthenticated');
        return;
      }

      try {
        const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000/api';
        const res = await fetch(`${BASE_URL}/v1/auth/me`, {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Accept': 'application/json',
          },
        });

        if (!res.ok) {
          setAuthState('unauthenticated');
          return;
        }

        const json = await res.json();
        const user = json.data;

        if (user.role === 'admin' || user.role === 'super_admin') {
          setAdminUser({
            id: user.id,
            name: user.name,
            role: user.role,
            role_label: user.role === 'super_admin' ? 'مشرف عام' : 'مشرف',
          });
          localStorage.setItem('admin_user', JSON.stringify(user));
          setAuthState('ok');
        } else {
          setAuthState('denied');
        }
      } catch {
        setAuthState('unauthenticated');
      }
    };

    checkAuth();
  }, []);

  // Redirect to admin login
  useEffect(() => {
    if (authState === 'unauthenticated') {
      router.push('/admin/login');
    }
  }, [authState, router]);

  if (authState === 'loading') {
    return (
      <div className={styles.loadingOverlay}>
        <div className={styles.loadingSpinner}>
          <div className={styles.spinner} />
          <span>جاري التحقق من الصلاحيات...</span>
        </div>
      </div>
    );
  }

  if (authState === 'unauthenticated') {
    return (
      <div className={styles.loadingOverlay}>
        <div className={styles.loadingSpinner}>
          <div className={styles.spinner} />
          <span>جاري التوجيه لصفحة الدخول...</span>
        </div>
      </div>
    );
  }

  if (authState === 'denied') {
    return (
      <div className={styles.accessDenied}>
        <h1>⛔ غير مصرح</h1>
        <p>ليس لديك صلاحيات للوصول إلى لوحة الإدارة. يرجى التواصل مع المشرف العام.</p>
        <a href="/" className={styles.backLink}>العودة للرئيسية</a>
      </div>
    );
  }

  return (
    <div className={`${styles.adminLayout} ${collapsed ? styles.collapsed : ''}`}>
      <AdminSidebar
        collapsed={collapsed}
        mobileOpen={mobileOpen}
        onToggleCollapse={() => setCollapsed(!collapsed)}
        onCloseMobile={() => setMobileOpen(false)}
      />

      <AdminHeader
        onToggleMobile={() => setMobileOpen(!mobileOpen)}
        adminName={adminUser?.name}
        adminRole={adminUser?.role_label}
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
