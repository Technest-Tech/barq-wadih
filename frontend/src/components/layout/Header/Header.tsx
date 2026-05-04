'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import Link from 'next/link';
import { useRouter, useParams, usePathname, useSearchParams } from 'next/navigation';
import { Search, Menu, X, Bell, Plus, Heart, MessageCircle, Bookmark, ChevronDown, ChevronLeft, User, FileText, LogOut, Settings, UserPlus } from 'lucide-react';
import { useAuthStore } from '@/store/auth.store';
import { authApi } from '@/lib/api/auth';
import AuthModal from '@/components/auth/AuthModal';
import { searchAds, type AdListItem } from '@/lib/api/ads';
import styles from './Header.module.css';

export default function Header() {
  const [menuOpen, setMenuOpen]     = useState(false);
  const [userDropOpen, setUserDropOpen] = useState(false);
  const [scrolled, setScrolled]     = useState(false);
  const [search, setSearch]         = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchResults, setSearchResults] = useState<AdListItem[]>([]);
  const [authOpen, setAuthOpen]     = useState(false);
  const [history, setHistory]       = useState<string[]>([]);

  const searchTimer  = useRef<NodeJS.Timeout>(null);
  const searchRef    = useRef<HTMLDivElement>(null);
  const userDropRef  = useRef<HTMLDivElement>(null);
  const inputRef     = useRef<HTMLInputElement>(null);

  const { user, isAuthenticated, clearAuth } = useAuthStore();
  const router       = useRouter();
  const params       = useParams();
  const pathname     = usePathname();
  const searchParams = useSearchParams();
  const locale       = (params?.locale as string) || 'ar';

  // Reflect URL ?q= back into the input so the search bar shows the active term.
  useEffect(() => {
    const q = searchParams?.get('q') ?? '';
    setSearch(q);
  }, [searchParams]);

  const HISTORY_KEY = 'barq:recent_searches';
  const HISTORY_MAX = 8;

  // Load history from localStorage on mount
  useEffect(() => {
    try {
      const raw = localStorage.getItem(HISTORY_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) setHistory(parsed.filter((s) => typeof s === 'string').slice(0, HISTORY_MAX));
      }
    } catch { /* ignore */ }
  }, []);

  const persistHistory = useCallback((next: string[]) => {
    setHistory(next);
    try { localStorage.setItem(HISTORY_KEY, JSON.stringify(next)); } catch { /* quota / private mode */ }
  }, []);

  const pushHistory = useCallback((term: string) => {
    const t = term.trim();
    if (!t) return;
    const next = [t, ...history.filter((x) => x !== t)].slice(0, HISTORY_MAX);
    persistHistory(next);
  }, [history, persistHistory]);

  const removeHistoryItem = useCallback((term: string) => {
    persistHistory(history.filter((x) => x !== term));
  }, [history, persistHistory]);

  const clearHistory = useCallback(() => {
    persistHistory([]);
  }, [persistHistory]);

  // Run a search inline: stay on home if already there, otherwise route to home with ?q=.
  const runSearch = useCallback((term: string) => {
    const t = term.trim();
    if (!t) return;
    pushHistory(t);
    setSearch(t);
    setSearchOpen(false);
    const onHome = pathname === `/${locale}` || pathname === `/${locale}/`;
    const url = `/${locale}?q=${encodeURIComponent(t)}`;
    if (onHome) router.replace(url); else router.push(url);
  }, [pathname, locale, router, pushHistory]);

  const displayName = user?.name?.split(' ')[0] ?? 'حسابي';
  const unreadNotif = user?.unread_notifications_count ?? 0;

  const handleLogout = async () => {
    setUserDropOpen(false);
    try { await authApi.logout(); } catch { /* ignore */ }
    clearAuth();
    router.replace(`/${locale}/login`);
  };

  // scroll shadow
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 10);
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  // close search dropdown on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setSearchOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // close user dropdown on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (userDropRef.current && !userDropRef.current.contains(e.target as Node)) {
        setUserDropOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // close drawer on Escape
  useEffect(() => {
    if (!menuOpen) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setMenuOpen(false); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [menuOpen]);

  // live search
  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    if (!search.trim()) { setSearchResults([]); return; }
    setSearchLoading(true);
    searchTimer.current = setTimeout(async () => {
      try {
        const res = await searchAds({ q: search.trim(), page: 1 });
        setSearchResults(res.data.slice(0, 8));
        // Only auto-open the dropdown when the input has focus (user is actively typing),
        // not when ?q= was hydrated from the URL.
        if (document.activeElement === inputRef.current) setSearchOpen(true);
      } catch { /* ignore */ } finally {
        setSearchLoading(false);
      }
    }, 350);
    return () => { if (searchTimer.current) clearTimeout(searchTimer.current); };
  }, [search]);

  // lock body scroll when mobile search or drawer is open
  useEffect(() => {
    const shouldLock = menuOpen || (searchOpen && window.innerWidth <= 639);
    document.body.style.overflow = shouldLock ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [menuOpen, searchOpen]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    runSearch(search);
  };

  return (
    <>
    <header
      className={`${styles.header} ${scrolled ? styles.scrolled : ''} ${searchOpen ? styles.headerLocked : ''}`}
      dir="rtl"
    >
      <div className={styles.inner}>

        {/* ── Logo ── */}
        <Link href={`/${locale}`} className={styles.logo}>
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
                      href={`/${locale}/ads/${ad.id}`}
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
                        {ad.is_free
                          ? <strong className={styles.freeTag}>بدون مقابل</strong>
                          : ad.price
                            ? <strong>{ad.price} ر.س</strong>
                            : <span>على السوم</span>
                        }
                      </div>
                    </Link>
                  ))}
                  {!searchLoading && searchResults.length > 0 && (
                    <button
                      type="button"
                      className={styles.searchViewAll}
                      onClick={() => runSearch(search)}
                    >
                      عرض كل النتائج →
                    </button>
                  )}
                </>
              ) : (
                <div className={styles.searchDefPanel}>
                  {history.length > 0 && (
                    <>
                      <div className={styles.searchDefHeader}>
                        <button type="button" className={styles.searchClearHist} onClick={clearHistory}>
                          <span className={styles.trashText}>مسح سجل البحث</span>
                          <span className={styles.trashIcon}>🗑️</span>
                        </button>
                      </div>
                      <div className={styles.searchHistList}>
                        {history.map(item => (
                          <div key={item} className={styles.searchHistItem}>
                            <button
                              type="button"
                              className={styles.searchHistMain}
                              onClick={() => runSearch(item)}
                            >
                              <span className={styles.searchHistIcon}>🕒</span>
                              <span className={styles.searchHistText}>{item}</span>
                            </button>
                            <button
                              type="button"
                              className={styles.searchHistDel}
                              onClick={(e) => { e.stopPropagation(); removeHistoryItem(item); }}
                              aria-label={`حذف ${item}`}
                            >
                              ✕
                            </button>
                          </div>
                        ))}
                      </div>
                    </>
                  )}
                  {history.length === 0 && (
                    <div className={styles.searchHistEmpty}>لا يوجد سجل بحث بعد</div>
                  )}
                  <div className={styles.searchTrendHeader}>
                    <span className={styles.searchTrendIcon}>📈</span>
                    <span className={styles.searchTrendText}>رائج</span>
                  </div>
                  <div className={styles.searchTrendList}>
                    {['تموينات للبيع', 'شحن', 'تذاكر الاهلي', 'سداد', 'حوش للبيع', 'مكيف سبيلت', 'منسق ورد', 'غرفة عامل'].map(item => (
                      <button
                        key={item}
                        className={styles.searchTrendItem}
                        onClick={() => runSearch(item)}
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
              {/* Quick nav links — Haraj style */}
              <nav className={styles.quickNav}>
                <Link href={`/${locale}/messages`} className={styles.quickNavItem}>
                  <MessageCircle size={18} />
                  <span>الرسائل</span>
                </Link>
                <Link href={`/${locale}/notifications`} className={styles.quickNavItem}>
                  <Bell size={18} />
                  <span>الإشعارات</span>
                  {unreadNotif > 0 && (
                    <span className={styles.badge}>{unreadNotif > 99 ? '99+' : unreadNotif}</span>
                  )}
                </Link>
                <Link href={`/${locale}/favorites`} className={styles.quickNavItem}>
                  <Heart size={18} />
                  <span>المفضلة</span>
                </Link>
                <Link href={`/${locale}/follows`} className={styles.quickNavItem}>
                  <UserPlus size={18} />
                  <span>المتابَعون</span>
                </Link>
              </nav>

              {/* Add listing CTA */}
              <Link href={`/${locale}/post-ad`} className={styles.postBtn}>
                <Plus size={16} />
                أضف إعلان
              </Link>

              {/* User avatar + name dropdown */}
              <div className={styles.userMenu} ref={userDropRef}>
                <button
                  className={styles.userMenuTrigger}
                  onClick={() => setUserDropOpen(v => !v)}
                  aria-expanded={userDropOpen}
                  aria-haspopup="true"
                >
                  <div className={styles.avatarWrap}>
                    {user?.avatar_url
                      ? <img src={user.avatar_url} alt={user.name} className={styles.avatar} />
                      : <span className={styles.avatarInitial}>{user?.name?.[0] ?? 'م'}</span>
                    }
                  </div>
                  <span className={styles.userName}>{displayName}</span>
                  <ChevronDown size={14} className={`${styles.chevron} ${userDropOpen ? styles.chevronOpen : ''}`} />
                </button>

                {userDropOpen && (
                  <div className={styles.userDropdown}>
                    <div className={styles.userDropHeader}>
                      <div className={styles.userDropAvatar}>
                        {user?.avatar_url
                          ? <img src={user.avatar_url} alt={user.name} className={styles.avatar} />
                          : <span className={styles.avatarInitial}>{user?.name?.[0] ?? 'م'}</span>
                        }
                      </div>
                      <div className={styles.userDropInfo}>
                        <span className={styles.userDropName}>{user?.name}</span>
                        <span className={styles.userDropEmail}>{user?.email ?? user?.phone}</span>
                      </div>
                    </div>
                    <div className={styles.userDropDivider} />
                    <Link href={`/${locale}/profile`} className={styles.userDropItem} onClick={() => setUserDropOpen(false)}>
                      <User size={16} /> حسابي
                    </Link>
                    <Link href={`/${locale}/follows`} className={styles.userDropItem} onClick={() => setUserDropOpen(false)}>
                      <UserPlus size={16} /> المتابَعون
                    </Link>
                    <Link href={`/${locale}/my-ads`} className={styles.userDropItem} onClick={() => setUserDropOpen(false)}>
                      <FileText size={16} /> إعلاناتي
                    </Link>
                    <Link href={`/${locale}/favorites`} className={styles.userDropItem} onClick={() => setUserDropOpen(false)}>
                      <Heart size={16} /> المفضلة
                    </Link>
                    <div className={styles.userDropDivider} />
                    <button className={`${styles.userDropItem} ${styles.userDropLogout}`} onClick={handleLogout}>
                      <LogOut size={16} /> تسجيل الخروج
                    </button>
                  </div>
                )}
              </div>
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

          {/* Mobile hamburger */}
          <button className={styles.menuBtn} onClick={() => setMenuOpen(m => !m)} aria-label="القائمة">
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </div>

      <AuthModal isOpen={authOpen} onClose={() => setAuthOpen(false)} />
    </header>

    {/* ── Mobile drawer overlay ── */}
    <div
      className={`${styles.drawerOverlay} ${menuOpen ? styles.drawerOverlayVisible : ''}`}
      onClick={() => setMenuOpen(false)}
      aria-hidden="true"
    />

    {/* ── Mobile drawer ── */}
    <aside
      className={`${styles.drawer} ${menuOpen ? styles.drawerOpen : ''}`}
      dir="rtl"
      aria-hidden={!menuOpen}
      aria-label="القائمة الرئيسية"
    >
      {/* Header */}
      <div className={styles.drawerHead}>
        <img src="/images/logo_nobg.png" alt="برق واضح" className={styles.drawerLogo} />
        <button className={styles.drawerClose} onClick={() => setMenuOpen(false)} aria-label="إغلاق">
          <X size={22} />
        </button>
      </div>

      {/* Profile / guest section */}
      {isAuthenticated ? (
        <div className={styles.drawerProfile}>
          <div className={styles.drawerAvatarLg}>
            {user?.avatar_url
              ? <img src={user.avatar_url} alt={user.name} className={styles.avatar} />
              : <span className={styles.drawerAvatarInitial}>{user?.name?.[0] ?? 'م'}</span>
            }
          </div>
          <div className={styles.drawerProfileInfo}>
            <span className={styles.drawerProfileName}>{user?.name}</span>
            <span className={styles.drawerProfileSub}>{user?.email ?? user?.phone}</span>
          </div>
        </div>
      ) : (
        <div className={styles.drawerGuestCard}>
          <p className={styles.drawerGuestTitle}>أهلاً بك في برق واضح</p>
          <p className={styles.drawerGuestSub}>سجّل دخولك للوصول لحسابك وإعلاناتك</p>
          <div className={styles.drawerAuthBtns}>
            <button className={styles.drawerLoginBtn} onClick={() => { setMenuOpen(false); setAuthOpen(true); }}>
              تسجيل الدخول
            </button>
            <button className={styles.drawerRegBtn} onClick={() => { setMenuOpen(false); setAuthOpen(true); }}>
              إنشاء حساب جديد
            </button>
          </div>
        </div>
      )}

      {/* Navigation */}
      {isAuthenticated && (
        <nav className={styles.drawerNav}>
          <div className={styles.drawerNavGroup}>
            <Link href={`/${locale}/profile`} className={styles.drawerNavItem} onClick={() => setMenuOpen(false)}>
              <User size={20} className={styles.drawerNavIcon} />
              <span>حسابي</span>
              <ChevronLeft size={16} className={styles.drawerNavChevron} />
            </Link>
            <Link href={`/${locale}/messages`} className={styles.drawerNavItem} onClick={() => setMenuOpen(false)}>
              <MessageCircle size={20} className={styles.drawerNavIcon} />
              <span>الرسائل</span>
              <ChevronLeft size={16} className={styles.drawerNavChevron} />
            </Link>
            <Link href={`/${locale}/notifications`} className={styles.drawerNavItem} onClick={() => setMenuOpen(false)}>
              <Bell size={20} className={styles.drawerNavIcon} />
              <span>الإشعارات</span>
              {unreadNotif > 0 && <span className={styles.drawerBadge}>{unreadNotif > 99 ? '99+' : unreadNotif}</span>}
              <ChevronLeft size={16} className={styles.drawerNavChevron} />
            </Link>
            <Link href={`/${locale}/favorites`} className={styles.drawerNavItem} onClick={() => setMenuOpen(false)}>
              <Heart size={20} className={styles.drawerNavIcon} />
              <span>المفضلة</span>
              <ChevronLeft size={16} className={styles.drawerNavChevron} />
            </Link>
            <Link href={`/${locale}/follows`} className={styles.drawerNavItem} onClick={() => setMenuOpen(false)}>
              <UserPlus size={20} className={styles.drawerNavIcon} />
              <span>المتابَعون</span>
              <ChevronLeft size={16} className={styles.drawerNavChevron} />
            </Link>
          </div>

          <div className={styles.drawerNavDivider} />

          <div className={styles.drawerNavGroup}>
            <Link href={`/${locale}/my-ads`} className={styles.drawerNavItem} onClick={() => setMenuOpen(false)}>
              <FileText size={20} className={styles.drawerNavIcon} />
              <span>إعلاناتي</span>
              <ChevronLeft size={16} className={styles.drawerNavChevron} />
            </Link>
          </div>

          <div className={styles.drawerNavDivider} />

          <button className={`${styles.drawerNavItem} ${styles.drawerLogout}`} onClick={handleLogout}>
            <LogOut size={20} className={styles.drawerNavIcon} />
            <span>تسجيل الخروج</span>
          </button>
        </nav>
      )}

      {/* Footer CTA */}
      <div className={styles.drawerFooter}>
        {isAuthenticated ? (
          <Link href={`/${locale}/post-ad`} className={styles.drawerPostBtn} onClick={() => setMenuOpen(false)}>
            <Plus size={18} />
            <span>أضف إعلان مجاناً</span>
          </Link>
        ) : (
          <button className={styles.drawerPostBtn} onClick={() => { setMenuOpen(false); setAuthOpen(true); }}>
            <Plus size={18} />
            <span>أضف إعلان مجاناً</span>
          </button>
        )}
      </div>
    </aside>
    </>
  );
}
