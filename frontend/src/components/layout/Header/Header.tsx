'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Search, Menu, X, Bell, Plus, ChevronDown, User } from 'lucide-react';
import { useAuthStore } from '@/store/auth.store';
import styles from './Header.module.css';

export default function Header() {
  const [menuOpen, setMenuOpen]   = useState(false);
  const [scrolled, setScrolled]   = useState(false);
  const [search, setSearch]       = useState('');
  const { user, isAuthenticated, clearAuth } = useAuthStore();
  const router                    = useRouter();
  const inputRef                  = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (search.trim()) router.push(`/ar/search?q=${encodeURIComponent(search.trim())}`);
  };

  return (
    <header className={`${styles.header} ${scrolled ? styles.scrolled : ''}`} dir="rtl">
      <div className={styles.inner}>

        {/* ── Logo ── */}
        <Link href="/ar" className={styles.logo}>
          <span className={styles.logoIcon}>⚡</span>
          <span className={styles.logoText}>برق <strong>واضح</strong></span>
        </Link>

        {/* ── Search bar (desktop) ── */}
        <form className={styles.searchWrap} onSubmit={handleSearch}>
          <button type="submit" className={styles.searchBtn} aria-label="بحث">
            <Search size={18} />
          </button>
          <input
            ref={inputRef}
            className={styles.searchInput}
            type="search"
            placeholder="ابحث عن سيارات، عقارات، إلكترونيات..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </form>

        {/* ── Desktop actions ── */}
        <div className={styles.actions}>
          {isAuthenticated ? (
            <>
              <button className={styles.iconBtn} aria-label="الإشعارات">
                <Bell size={20} />
                <span className={styles.notifDot} />
              </button>
              <Link href="/ar/ads/create" className={styles.postBtn}>
                <Plus size={16} />
                أضف إعلان
              </Link>
              <button className={styles.avatarBtn} onClick={() => clearAuth()}>
                {user?.avatar_url
                  ? <img src={user.avatar_url} alt={user.name} className={styles.avatar} />
                  : <span className={styles.avatarInitial}>{user?.name?.[0] ?? 'م'}</span>
                }
              </button>
            </>
          ) : (
            <>
              <Link href="/ar/login"    className={styles.loginBtn}>تسجيل الدخول</Link>
              <Link href="/ar/register" className={styles.postBtn}>
                <Plus size={16} />
                أضف إعلان
              </Link>
            </>
          )}
          <button className={styles.menuBtn} onClick={() => setMenuOpen(m => !m)} aria-label="القائمة">
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </div>

      {/* ── Mobile search ── */}
      <form className={styles.mobileSearch} onSubmit={handleSearch}>
        <Search size={16} className={styles.mobileSearchIcon} />
        <input
          className={styles.mobileSearchInput}
          type="search"
          placeholder="ابحث..."
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </form>

      {/* ── Mobile menu ── */}
      {menuOpen && (
        <nav className={styles.mobileMenu} onClick={() => setMenuOpen(false)}>
          {isAuthenticated
            ? <>
                <Link href="/ar/profile"    className={styles.mobileLink}>حسابي</Link>
                <Link href="/ar/my-ads"     className={styles.mobileLink}>إعلاناتي</Link>
                <Link href="/ar/favorites"  className={styles.mobileLink}>المفضلة</Link>
                <button className={`${styles.mobileLink} ${styles.logoutLink}`} onClick={clearAuth}>تسجيل الخروج</button>
              </>
            : <>
                <Link href="/ar/login"    className={styles.mobileLink}>تسجيل الدخول</Link>
                <Link href="/ar/register" className={styles.mobileLink}>إنشاء حساب</Link>
              </>
          }
        </nav>
      )}
    </header>
  );
}
