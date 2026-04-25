'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Search, Menu, X, Bell, Plus, ChevronDown, User } from 'lucide-react';
import { useAuthStore } from '@/store/auth.store';
import AuthModal from '@/components/auth/AuthModal';
import { searchAds, type AdListItem } from '@/lib/api/ads';
import styles from './Header.module.css';

export default function Header() {
  const [menuOpen, setMenuOpen]   = useState(false);
  const [scrolled, setScrolled]   = useState(false);
  const [search, setSearch]       = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchResults, setSearchResults] = useState<AdListItem[]>([]);
  const searchTimer = useRef<NodeJS.Timeout>(null);
  const searchRef = useRef<HTMLDivElement>(null);
  const [authOpen, setAuthOpen]   = useState(false);
  const { user, isAuthenticated, clearAuth } = useAuthStore();
  const router                    = useRouter();
  const inputRef                  = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setSearchOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    if (!search.trim()) { setSearchResults([]); setSearchOpen(false); return; }
    setSearchLoading(true);
    searchTimer.current = setTimeout(async () => {
      try {
        const res = await searchAds({ q: search.trim(), page: 1 });
        setSearchResults(res.data.slice(0, 8));
        setSearchOpen(true);
      } catch { /* ignore */ } finally {
        setSearchLoading(false);
      }
    }, 350);
    return () => { if (searchTimer.current) clearTimeout(searchTimer.current); };
  }, [search]);

  useEffect(() => {
    if (searchOpen && window.innerWidth <= 639) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [searchOpen]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (search.trim()) router.push(`/ar/search?q=${encodeURIComponent(search.trim())}`);
  };

  return (
    <header className={`${styles.header} ${scrolled ? styles.scrolled : ''} ${searchOpen ? styles.headerLocked : ''}`} dir="rtl">
      <div className={styles.inner}>

        {/* ── Logo ── */}
        <Link href="/ar" className={styles.logo}>
          <img src="/images/logo_nobg.png" alt="برق واضح" className={styles.logoImg} />
        </Link>

        {/* ── Search bar ── */}
        <div className={styles.searchWrap} ref={searchRef}>
          <form className={styles.searchForm} onSubmit={handleSearch}>
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
              onFocus={() => setSearchOpen(true)}
              autoComplete="off"
            />
            {search && (
              <button type="button" className={styles.searchClear} onClick={() => { setSearch(''); setSearchOpen(true); }}>✕</button>
            )}
          </form>

          {/* Live search results & Default Suggestions */}
          {searchOpen && (
            <div className={styles.searchDropdown}>
              {search ? (
                <>
                  {searchLoading && (
                    <div className={styles.searchLoading}>
                      <span className={styles.searchSpinner} /> جارٍ البحث...
                    </div>
                  )}
                  {!searchLoading && searchResults.length === 0 && (
                    <div className={styles.searchEmpty}>لا توجد نتائج لـ «{search}»</div>
                  )}
                  {!searchLoading && searchResults.map(ad => (
                    <Link
                      key={ad.id}
                      href={`/ar/ads/${ad.id}`}
                      className={styles.searchResult}
                      onClick={() => setSearchOpen(false)}
                    >
                      <div className={styles.searchResultImg}>
                        {ad.primary_image ? <img src={ad.primary_image.thumbnail_url} alt="" /> : '📷'}
                      </div>
                      <div className={styles.searchResultInfo}>
                        <div className={styles.searchResultTitle}>{ad.title}</div>
                        <div className={styles.searchResultMeta}>
                          <span>{ad.city?.name_ar}</span>
                          <span>•</span>
                          <span className={styles.searchTime}>{new Date(ad.created_at).toLocaleDateString('ar-SA')}</span>
                        </div>
                      </div>
                      <div className={styles.searchResultPrice}>
                        {ad.is_free ? <strong className={styles.freeTag}>بدون مقابل</strong> : ad.price ? <strong>{ad.price} ر.س</strong> : <span>على السوم</span>}
                      </div>
                    </Link>
                  ))}
                  {!searchLoading && searchResults.length > 0 && (
                    <Link
                      href={`/ar/search?q=${encodeURIComponent(search)}`}
                      className={styles.searchViewAll}
                      onClick={() => setSearchOpen(false)}
                    >
                      عرض كل النتائج →
                    </Link>
                  )}
                </>
              ) : (
                /* Default panel when query is empty */
                <div className={styles.searchDefPanel}>
                  {/* Header: Clear History */}
                  <div className={styles.searchDefHeader}>
                    <button className={styles.searchClearHist}>
                      <span className={styles.trashText}>مسح سجل البحث</span>
                      <span className={styles.trashIcon}>🗑️</span>
                    </button>
                  </div>

                  {/* History items */}
                  <div className={styles.searchHistList}>
                    {['الرئيسية', 'اطعمة'].map(item => (
                      <div key={item} className={styles.searchHistItem}>
                        <span className={styles.searchHistIcon}>🕒</span>
                        <span className={styles.searchHistText}>{item}</span>
                        <button className={styles.searchHistDel}>✕</button>
                      </div>
                    ))}
                  </div>

                  {/* Trending Header */}
                  <div className={styles.searchTrendHeader}>
                    <span className={styles.searchTrendIcon}>📈</span>
                    <span className={styles.searchTrendText}>رائج</span>
                  </div>

                  {/* Trending items */}
                  <div className={styles.searchTrendList}>
                    {['تموينات للبيع', 'شحن', 'تذاكر الاهلي', 'سداد', 'حوش للبيع', 'مكيف سبيلت', 'منسق ورد', 'غرفة عامل'].map(item => (
                      <button
                        key={item}
                        className={styles.searchTrendItem}
                        onClick={() => {
                          setSearch(item);
                          setSearchOpen(false);
                          router.push(`/ar/search?q=${encodeURIComponent(item)}`);
                        }}
                      >
                        <span className={styles.searchTrendIcon}>🔥</span>
                        <span className={styles.searchTrendText}>{item}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

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
              <button onClick={() => setAuthOpen(true)} className={styles.loginBtn}>تسجيل الدخول</button>
              <button onClick={() => setAuthOpen(true)} className={styles.postBtn}>
                <Plus size={16} />
                أضف إعلان
              </button>
            </>
          )}
          <button className={styles.menuBtn} onClick={() => setMenuOpen(m => !m)} aria-label="القائمة">
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </div>

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
                <button onClick={() => setAuthOpen(true)} className={styles.mobileLink}>تسجيل الدخول</button>
                <button onClick={() => setAuthOpen(true)} className={styles.mobileLink}>إنشاء حساب</button>
              </>
          }
        </nav>
      )}
      {/* ── Auth Modal ── */}
      <AuthModal isOpen={authOpen} onClose={() => setAuthOpen(false)} />
    </header>
  );
}
