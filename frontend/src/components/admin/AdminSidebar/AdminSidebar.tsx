'use client';

import Link from 'next/link';
import Image from 'next/image';
import { useEffect, useState } from 'react';
import { usePathname, useParams } from 'next/navigation';
import { fetchPaymentProofPendingCount } from '@/lib/api/admin-payment-proofs';
import styles from './AdminSidebar.module.css';

interface NavItem {
  href: string;
  label: string;
  icon: React.ReactNode;
  badge?: boolean;
  /** Which live counter to show as a badge, if any. */
  badgeCount?: 'reports' | 'payments';
  disabled?: boolean;
}

interface AdminSidebarProps {
  collapsed: boolean;
  mobileOpen: boolean;
  onToggleCollapse: () => void;
  onCloseMobile: () => void;
  pendingReports?: number;
  adminName?: string;
  adminRole?: string;
}

const S = {
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: '2',
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
};

const NAV_SECTIONS = [
  {
    label: 'الرئيسية',
    items: [
      {
        href: '/admin',
        label: 'لوحة التحكم',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <rect x="3" y="3" width="8" height="8" rx="1.5" />
            <rect x="13" y="3" width="8" height="8" rx="1.5" />
            <rect x="3" y="13" width="8" height="8" rx="1.5" />
            <rect x="13" y="13" width="8" height="8" rx="1.5" />
          </svg>
        ),
      },
      {
        href: '/admin/users',
        label: 'المستخدمين',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        ),
      },
    ],
  },
  {
    label: 'إدارة المحتوى',
    items: [
      {
        href: '/admin/ads',
        label: 'الإعلانات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
          </svg>
        ),
      },
      {
        href: '/admin/reports',
        label: 'البلاغات',
        badge: true,
        badgeCount: 'reports',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" />
            <line x1="4" y1="22" x2="4" y2="15" />
          </svg>
        ),
      },
      {
        href: '/admin/categories',
        label: 'التصنيفات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
          </svg>
        ),
      },
      {
        href: '/admin/regions',
        label: 'المناطق والمدن',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
            <circle cx="12" cy="10" r="3" />
          </svg>
        ),
      },
      {
        href: '/admin/pages',
        label: 'الصفحات الثابتة',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="16" y1="13" x2="8" y2="13" />
            <line x1="16" y1="17" x2="8" y2="17" />
          </svg>
        ),
      },
    ],
  },
  {
    label: 'المالية والتحليلات',
    items: [
      {
        href: '/admin/commissions',
        label: 'العمولات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <line x1="12" y1="1" x2="12" y2="23" />
            <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
          </svg>
        ),
      },
      {
        href: '/admin/payment-proofs',
        label: 'التحويلات البنكية',
        badgeCount: 'payments',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <rect x="2" y="5" width="20" height="14" rx="2" />
            <line x1="2" y1="10" x2="22" y2="10" />
          </svg>
        ),
      },
      {
        href: '/admin/analytics',
        label: 'التحليلات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <line x1="18" y1="20" x2="18" y2="10" />
            <line x1="12" y1="20" x2="12" y2="4" />
            <line x1="6" y1="20" x2="6" y2="14" />
          </svg>
        ),
      },
      {
        href: '/admin/search-analytics',
        label: 'تحليلات البحث',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
        ),
      },
      {
        href: '/admin/banners',
        label: 'البانرات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <circle cx="8.5" cy="8.5" r="1.5" />
            <polyline points="21 15 16 10 5 21" />
          </svg>
        ),
      },
    ],
  },
  {
    label: 'النظام',
    items: [
      {
        href: '/admin/contact',
        label: 'تواصل معنا',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
          </svg>
        ),
      },
      {
        href: '/admin/notifications',
        label: 'الإشعارات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
            <path d="M13.73 21a2 2 0 0 1-3.46 0" />
          </svg>
        ),
      },
      {
        href: '/admin/settings',
        label: 'الإعدادات',
        icon: (
          <svg width="18" height="18" viewBox="0 0 24 24" {...S}>
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
          </svg>
        ),
      },
    ],
  },
] as { label: string; items: NavItem[] }[];

export default function AdminSidebar({
  collapsed,
  mobileOpen,
  onToggleCollapse,
  onCloseMobile,
  pendingReports = 0,
  adminName = 'المشرف',
  adminRole = 'مشرف عام',
}: AdminSidebarProps) {
  const pathname = usePathname();
  const params = useParams();
  const locale = (params?.locale as string) || 'ar';

  const [pendingPayments, setPendingPayments] = useState(0);
  useEffect(() => {
    fetchPaymentProofPendingCount()
      .then(setPendingPayments)
      .catch(() => {});
  }, [pathname]);

  const isActive = (href: string) => {
    // Strip locale prefix only when it actually exists in the URL
    // The lookahead (?=\/|$) prevents stripping e.g. /admin → /admin (not /min)
    const clean = pathname.replace(/^\/[a-z]{2}(?=\/|$)/, '');
    if (href === '/admin') return clean === '/admin';
    return clean.startsWith(href);
  };

  const initials = adminName
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2);

  return (
    <aside
      className={`${styles.sidebar} ${collapsed ? styles.collapsed : ''} ${mobileOpen ? styles.mobileOpen : ''}`}
    >
      {/* Logo */}
      <div className={styles.logoSection}>
        <div className={styles.logoMark}>
          <Image
            src="/images/logo_nobg.png"
            alt="برق واضح"
            width={32}
            height={32}
            className={styles.logoImg}
            priority
          />
        </div>
        <div className={styles.logoText}>
          <span className={styles.logoName}>برق واضح</span>
          <span className={styles.logoSub}>لوحة الإدارة</span>
        </div>
      </div>

      {/* Nav */}
      <nav className={styles.nav}>
        {NAV_SECTIONS.map((section) => (
          <div key={section.label} className={styles.section}>
            <p className={styles.sectionLabel}>{section.label}</p>
            {section.items.map((item) => {
              const active = isActive(item.href);
              const badgeValue =
                item.badgeCount === 'payments'
                  ? pendingPayments
                  : item.badgeCount === 'reports'
                    ? pendingReports
                    : 0;
              const showBadge = badgeValue > 0;
              if (item.disabled) {
                return (
                  <div
                    key={item.href}
                    className={`${styles.item} ${styles.disabled}`}
                    title={item.label}
                  >
                    <span className={styles.icon}>{item.icon}</span>
                    <span className={styles.label}>{item.label}</span>
                  </div>
                );
              }
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`${styles.item} ${active ? styles.active : ''}`}
                  onClick={onCloseMobile}
                  title={collapsed ? item.label : undefined}
                >
                  <span className={styles.icon}>{item.icon}</span>
                  <span className={styles.label}>{item.label}</span>
                  {showBadge && <span className={styles.badge}>{badgeValue}</span>}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      {/* Footer */}
      <div className={styles.footer}>
        <div className={styles.userRow}>
          <div className={styles.avatar}>{initials}</div>
          <div className={styles.userText}>
            <span className={styles.userName}>{adminName}</span>
            <span className={styles.userRole}>{adminRole}</span>
          </div>
        </div>

        <button
          className={styles.collapseBtn}
          onClick={onToggleCollapse}
          title={collapsed ? 'توسيع' : 'طي'}
        >
          <span className={`${styles.chevron} ${collapsed ? styles.chevronFlipped : ''}`}>
            <svg
              width="15"
              height="15"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <polyline points="15 18 9 12 15 6" />
            </svg>
          </span>
          <span className={styles.collapseLabel}>طي القائمة</span>
        </button>
      </div>
    </aside>
  );
}
