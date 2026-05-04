'use client';

import { useParams, usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import { authApi } from '@/lib/api/auth';
import { useAuthStore } from '@/store/auth.store';
import styles from './AdminHeader.module.css';

interface AdminHeaderProps {
  onToggleMobile: () => void;
  adminName?: string;
  adminRole?: string;
}

const ROUTE_LABELS: Record<string, string> = {
  admin: 'لوحة التحكم',
  users: 'المستخدمين',
  ads: 'الإعلانات',
  reports: 'البلاغات',
  categories: 'التصنيفات',
  regions: 'المناطق والمدن',
  pages: 'الصفحات الثابتة',
  commissions: 'العمولات',
  analytics: 'التحليلات',
  'search-analytics': 'تحليلات البحث',
  banners: 'البانرات',
  notifications: 'الإشعارات',
  settings: 'الإعدادات',
};

export default function AdminHeader({ onToggleMobile, adminName = 'المشرف', adminRole = 'مشرف عام' }: AdminHeaderProps) {
  const pathname = usePathname();
  const router = useRouter();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';
  const { clearAuth } = useAuthStore();

  // Current page label from last path segment
  const segments = pathname.replace(/^\/[a-z]{2}\//, '').split('/').filter(Boolean);
  const currentLabel = ROUTE_LABELS[segments[segments.length - 1]] ?? segments[segments.length - 1] ?? 'لوحة التحكم';
  const isHome = segments.length <= 1;

  // Breadcrumbs
  const crumbs = segments.map((seg, i) => ({
    label: ROUTE_LABELS[seg] ?? seg,
    href: `/${locale}/${segments.slice(0, i + 1).join('/')}`,
    last: i === segments.length - 1,
  }));

  const handleLogout = async () => {
    try { await authApi.logout(); } catch { /* continue */ }
    clearAuth();
    router.replace(`/${locale}/admin/login`);
  };

  const initials = adminName.split(' ').map((w) => w[0]).join('').slice(0, 2);

  return (
    <header className={styles.header}>

      {/* Left side (RTL: start) */}
      <div className={styles.start}>
        {/* Mobile hamburger */}
        <button className={styles.menuBtn} onClick={onToggleMobile} aria-label="القائمة">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <line x1="3" y1="6" x2="21" y2="6"/>
            <line x1="3" y1="12" x2="21" y2="12"/>
            <line x1="3" y1="18" x2="21" y2="18"/>
          </svg>
        </button>

        {/* Page title + breadcrumb */}
        <div className={styles.titleBlock}>
          {!isHome && (
            <nav className={styles.breadcrumb}>
              <Link href={`/${locale}/admin`} className={styles.crumbLink}>لوحة التحكم</Link>
              {crumbs.slice(1).map((c) => (
                <span key={c.href} className={styles.crumbGroup}>
                  <span className={styles.crumbSep}>/</span>
                  {c.last
                    ? <span className={styles.crumbCurrent}>{c.label}</span>
                    : <Link href={c.href} className={styles.crumbLink}>{c.label}</Link>
                  }
                </span>
              ))}
            </nav>
          )}
        </div>
      </div>

      {/* Right side (RTL: end) */}
      <div className={styles.end}>
        {/* Notification bell */}
        <button className={styles.iconBtn} aria-label="الإشعارات">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
        </button>

        {/* Divider */}
        <span className={styles.divider} />

        {/* Profile */}
        <div className={styles.profileChip}>
          <div className={styles.profileAvatar}>{initials}</div>
          <div className={styles.profileInfo}>
            <span className={styles.profileName}>{adminName}</span>
            <span className={styles.profileRole}>{adminRole}</span>
          </div>
        </div>

        {/* Logout */}
        <button className={styles.logoutBtn} onClick={handleLogout} title="تسجيل الخروج">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
            <polyline points="16 17 21 12 16 7"/>
            <line x1="21" y1="12" x2="9" y2="12"/>
          </svg>
        </button>
      </div>
    </header>
  );
}
