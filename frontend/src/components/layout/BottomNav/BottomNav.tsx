'use client';

import Link from 'next/link';
import { usePathname, useParams } from 'next/navigation';
import { Home, Heart, Plus, MessageCircle, User } from 'lucide-react';
import { useAuthStore } from '@/store/auth.store';
import styles from './BottomNav.module.css';

interface BottomNavProps {
  onAuthOpen: () => void;
}

export default function BottomNav({ onAuthOpen }: BottomNavProps) {
  const pathname = usePathname();
  const params   = useParams();
  const { isAuthenticated } = useAuthStore();
  const locale   = (params?.locale as string) || 'ar';

  const isHome      = pathname === `/${locale}` || pathname === `/${locale}/`;
  const isFavorites = pathname === `/${locale}/favorites`;
  const isMessages  = pathname === `/${locale}/messages`;
  const isProfile   = pathname === `/${locale}/profile`;

  const handlePostAd = () => {
    if (!isAuthenticated) {
      onAuthOpen();
    } else {
      window.location.href = `/${locale}/post-ad`;
    }
  };

  const handleFavorites = () => {
    if (!isAuthenticated) {
      onAuthOpen();
    } else {
      window.location.href = `/${locale}/favorites`;
    }
  };

  const handleProfile = () => {
    if (!isAuthenticated) {
      onAuthOpen();
    } else {
      window.location.href = `/${locale}/profile`;
    }
  };

  return (
    <nav className={styles.bottomNav} dir="rtl">
      {/* Home */}
      <Link href={`/${locale}`} className={`${styles.navItem} ${isHome ? styles.navItemActive : ''}`}>
        <Home size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>الرئيسية</span>
      </Link>

      {/* Favorites */}
      <button
        className={`${styles.navItem} ${isFavorites ? styles.navItemActive : ''}`}
        onClick={handleFavorites}
      >
        <Heart size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>المفضلة</span>
      </button>

      {/* Post Ad (center — accent button) */}
      <button className={styles.navItemPost} onClick={handlePostAd}>
        <div className={styles.postCircle}>
          <Plus size={26} strokeWidth={2.5} />
        </div>
        <span className={styles.navLabel}>أضف</span>
      </button>

      {/* Messages */}
      <button
        className={`${styles.navItem} ${isMessages ? styles.navItemActive : ''}`}
        onClick={() => isAuthenticated ? window.location.href = `/${locale}/messages` : onAuthOpen()}
      >
        <MessageCircle size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>الرسائل</span>
      </button>

      {/* Profile */}
      <button
        className={`${styles.navItem} ${isProfile ? styles.navItemActive : ''}`}
        onClick={handleProfile}
      >
        <User size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>حسابي</span>
      </button>
    </nav>
  );
}
