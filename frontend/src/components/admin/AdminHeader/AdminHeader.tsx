'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import styles from './AdminHeader.module.css';

interface AdminHeaderProps {
  onToggleMobile: () => void;
  adminName?: string;
  adminRole?: string;
}

const BREADCRUMB_MAP: Record<string, string> = {
  '/admin': 'لوحة التحكم',
  '/admin/users': 'المستخدمين',
};

export default function AdminHeader({
  onToggleMobile,
  adminName = 'المشرف',
  adminRole = 'مشرف عام',
}: AdminHeaderProps) {
  const pathname = usePathname();
  const router = useRouter();

  // Build breadcrumbs from pathname
  const cleanPath = pathname.replace(/^\/[a-z]{2}/, '');
  const segments = cleanPath.split('/').filter(Boolean);
  const breadcrumbs: { label: string; href: string }[] = [];

  let currentPath = '';
  for (const seg of segments) {
    currentPath += `/${seg}`;
    const label = BREADCRUMB_MAP[currentPath] || (seg.match(/^\d+$/) ? `#${seg}` : seg);
    breadcrumbs.push({ label, href: currentPath });
  }

  const handleLogout = () => {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('admin_user');
    router.push('/admin/login');
  };

  const initials = adminName
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2);

  return (
    <header className={styles.header}>
      <div className={styles.headerRight}>
        <button className={styles.menuBtn} onClick={onToggleMobile} aria-label="فتح القائمة">
          ☰
        </button>
        <nav className={styles.breadcrumb} aria-label="التنقل">
          {breadcrumbs.map((crumb, i) => (
            <span key={crumb.href}>
              {i > 0 && <span className={styles.breadcrumbSep}>/</span>}
              {i === breadcrumbs.length - 1 ? (
                <span className={styles.breadcrumbCurrent}>{crumb.label}</span>
              ) : (
                <Link href={crumb.href} className={styles.breadcrumbLink}>
                  {crumb.label}
                </Link>
              )}
            </span>
          ))}
        </nav>
      </div>

      <div className={styles.headerLeft}>
        <div className={styles.adminInfo}>
          <button className={styles.notifBtn} aria-label="الإشعارات">
            🔔
          </button>

          <div className={styles.adminProfile}>
            <div className={styles.adminAvatar}>{initials}</div>
            <div className={styles.adminMeta}>
              <span className={styles.adminName}>{adminName}</span>
              <span className={styles.adminRole}>{adminRole}</span>
            </div>
          </div>

          <button className={styles.logoutBtn} onClick={handleLogout} aria-label="تسجيل الخروج" title="تسجيل الخروج">
            🚪
          </button>
        </div>
      </div>
    </header>
  );
}
