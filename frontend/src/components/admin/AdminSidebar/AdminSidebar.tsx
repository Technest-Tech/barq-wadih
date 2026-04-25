'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import styles from './AdminSidebar.module.css';

interface NavItem {
  href: string;
  icon: string;
  label: string;
  badge?: number;
  disabled?: boolean;
}

interface AdminSidebarProps {
  collapsed: boolean;
  mobileOpen: boolean;
  onToggleCollapse: () => void;
  onCloseMobile: () => void;
  pendingReports?: number;
}

const NAV_SECTIONS: { label: string; items: NavItem[] }[] = [
  {
    label: 'الرئيسية',
    items: [
      { href: '/admin', icon: '📊', label: 'لوحة التحكم' },
      { href: '/admin/users', icon: '👥', label: 'المستخدمين' },
    ],
  },
  {
    label: 'إدارة المحتوى',
    items: [
      { href: '/admin/ads', icon: '📢', label: 'الإعلانات' },
      { href: '/admin/reports', icon: '⚠️', label: 'البلاغات' },
      { href: '/admin/categories', icon: '📂', label: 'التصنيفات' },
      { href: '/admin/regions', icon: '🗺️', label: 'المناطق والمدن' },
      { href: '/admin/pages', icon: '📄', label: 'الصفحات الثابتة' },
    ],
  },
  {
    label: 'المالية والتحليلات',
    items: [
      { href: '/admin/commissions', icon: '💰', label: 'العمولات' },
      { href: '/admin/analytics', icon: '📈', label: 'التحليلات' },
      { href: '/admin/search-analytics', icon: '🔍', label: 'تحليلات البحث' },
      { href: '/admin/banners', icon: '🖼️', label: 'البانرات' },
    ],
  },
  {
    label: 'النظام',
    items: [
      { href: '/admin/notifications', icon: '🔔', label: 'الإشعارات' },
      { href: '/admin/settings', icon: '⚙️', label: 'الإعدادات' },
    ],
  },
];

export default function AdminSidebar({
  collapsed,
  mobileOpen,
  onToggleCollapse,
  onCloseMobile,
  pendingReports = 0,
}: AdminSidebarProps) {
  const pathname = usePathname();

  const isActive = (href: string) => {
    // Remove locale prefix for matching
    const cleanPath = pathname.replace(/^\/[a-z]{2}/, '');
    if (href === '/admin') return cleanPath === '/admin';
    return cleanPath.startsWith(href);
  };

  return (
    <aside
      className={`${styles.sidebar} ${collapsed ? styles.collapsed : ''} ${mobileOpen ? styles.mobileOpen : ''}`}
    >
      {/* Logo */}
      <div className={styles.logoSection}>
        <div className={styles.logoIcon}>⚡</div>
        <div className={styles.logoText}>
          <span className={styles.logoTitle}>برق واضح</span>
          <span className={styles.logoSubtitle}>لوحة الإدارة</span>
        </div>
      </div>

      {/* Navigation */}
      <nav className={styles.nav}>
        {NAV_SECTIONS.map((section) => (
          <div key={section.label} className={styles.navSection}>
            <div className={styles.navSectionLabel}>{section.label}</div>
            {section.items.map((item) => {
              const badge = item.href === '/admin/reports' ? pendingReports : undefined;
              const itemDisabled = item.disabled;

              if (itemDisabled) {
                return (
                  <div
                    key={item.href}
                    className={`${styles.navItem} ${styles.navDisabled}`}
                    title={`${item.label} — قريباً`}
                  >
                    <span className={styles.navIcon}>{item.icon}</span>
                    <span className={styles.navLabel}>{item.label}</span>
                  </div>
                );
              }

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`${styles.navItem} ${isActive(item.href) ? styles.active : ''}`}
                  onClick={onCloseMobile}
                >
                  <span className={styles.navIcon}>{item.icon}</span>
                  <span className={styles.navLabel}>{item.label}</span>
                  {badge !== undefined && badge > 0 && (
                    <span className={styles.navBadge}>{badge}</span>
                  )}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      {/* Collapse Toggle */}
      <div className={styles.collapseSection}>
        <button className={styles.collapseBtn} onClick={onToggleCollapse}>
          <span className={`${styles.collapseIcon} ${collapsed ? styles.rotated : ''}`}>
            ◀
          </span>
          <span className={styles.collapseLabel}>طي القائمة</span>
        </button>
      </div>
    </aside>
  );
}
