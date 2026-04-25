'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Grid3X3, Plus, MessageCircle, User } from 'lucide-react';
import { useAuthStore } from '@/store/auth.store';
import styles from './BottomNav.module.css';

interface BottomNavProps {
  onCategoriesOpen: () => void;
  onAuthOpen: () => void;
}

export default function BottomNav({ onCategoriesOpen, onAuthOpen }: BottomNavProps) {
  const pathname = usePathname();
  const { isAuthenticated } = useAuthStore();

  const isHome = pathname === '/ar' || pathname === '/en';

  const handlePostAd = () => {
    if (!isAuthenticated) {
      onAuthOpen();
    } else {
      window.location.href = '/ar/post-ad';
    }
  };

  const handleProfile = () => {
    if (!isAuthenticated) {
      onAuthOpen();
    } else {
      window.location.href = '/ar/profile';
    }
  };

  return (
    <nav className={styles.bottomNav} dir="rtl">
      {/* Home */}
      <Link href="/ar" className={`${styles.navItem} ${isHome ? styles.navItemActive : ''}`}>
        <Home size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>الرئيسية</span>
      </Link>

      {/* Categories */}
      <button className={styles.navItem} onClick={onCategoriesOpen}>
        <Grid3X3 size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>الأقسام</span>
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
        className={styles.navItem}
        onClick={() => isAuthenticated ? window.location.href = '/ar/messages' : onAuthOpen()}
      >
        <MessageCircle size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>الرسائل</span>
      </button>

      {/* Profile */}
      <button className={styles.navItem} onClick={handleProfile}>
        <User size={22} className={styles.navIcon} />
        <span className={styles.navLabel}>حسابي</span>
      </button>
    </nav>
  );
}
