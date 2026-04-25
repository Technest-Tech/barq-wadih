'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import Link from 'next/link';
import Header from '@/components/layout/Header/Header';
import CategoryTabs from '@/components/layout/CategoryTabs/CategoryTabs';
import Footer from '@/components/layout/Footer/Footer';
import BottomNav from '@/components/layout/BottomNav/BottomNav';
import MobileDrawer from '@/components/layout/MobileDrawer/MobileDrawer';
import AuthModal from '@/components/auth/AuthModal';
import { fetchAllCities, type Region, type City } from '@/lib/api/regions';
import { fetchAds, searchAds, type AdListItem, type AdsFilters } from '@/lib/api/ads';
import { fetchCategories, type Category } from '@/lib/api/categories';
import BannerCarousel from '@/components/banners/BannerCarousel';
import styles from './page.module.css';

// ── Helpers ───────────────────────────────────────────────────────────────────
function relativeTime(dateStr: string | null): string {
  if (!dateStr) return '';
  const diffMs  = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1)  return 'الآن';
  if (diffMin < 60) return `منذ ${diffMin} د`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24)  return `منذ ${diffHr} س`;
  return `منذ ${Math.floor(diffHr / 24)} ي`;
}

const SORT_OPTS: { val: AdsFilters['sort']; label: string }[] = [
  { val: 'newest',     label: '⬇ الأحدث' },
  { val: 'price_asc',  label: '⬆ أقل سعر' },
  { val: 'price_desc', label: '⬇ أعلى سعر' },
];

// ── Page ──────────────────────────────────────────────────────────────────────
export default function HomePage() {
  // Location — flat searchable city list
  const [allCities, setAllCities]         = useState<City[]>([]);
  const [citySearch, setCitySearch]       = useState('');
  const [selectedCity, setSelectedCity]   = useState<City | null>(null);
  const [citiesLoading, setCitiesLoading] = useState(true);
  const [locationOpen, setLocationOpen]   = useState(false);
  // Keep selectedRegion for feed filtering compatibility
  const [selectedRegion, setSelectedRegion] = useState<Region | null>(null);
  const locationRef = useRef<HTMLDivElement>(null);

  // Search
  const [query, setQuery]               = useState('');
  const [searchResults, setSearchResults] = useState<AdListItem[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchOpen, setSearchOpen]     = useState(false);
  const searchRef = useRef<HTMLDivElement>(null);
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Feed
  const [ads, setAds]             = useState<AdListItem[]>([]);
  const [adsLoading, setAdsLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [sort, setSort]           = useState<AdsFilters['sort']>('newest');
  const [currentPage, setCurrentPage] = useState(1);
  const [lastPage, setLastPage]   = useState(1);
  const [total, setTotal]         = useState(0);
  const [viewMode, setViewMode]   = useState<'list' | 'grid'>('list');
  const [nearMe, setNearMe]     = useState(false);

  // Categories (quick nav & dropdown)
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<Category | null>(null);
  const [showMoreCats, setShowMoreCats] = useState(false);
  const [filterOpen, setFilterOpen] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [authOpen, setAuthOpen]     = useState(false);

  // Sidebar searchable category dropdown
  const [sbDropOpen, setSbDropOpen]       = useState(false);
  const [categorySearch, setCategorySearch] = useState('');
  const sbDropRef = useRef<HTMLDivElement>(null);

  // ── Boot ───────────────────────────────────────────────────────────────────
  useEffect(() => {
    setCitiesLoading(true);
    fetchAllCities()
      .then(setAllCities)
      .catch(console.error)
      .finally(() => setCitiesLoading(false));
    fetchCategories().then(setCategories).catch(console.error);
  }, []);

  // Close dropdowns on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (locationRef.current && !locationRef.current.contains(e.target as Node)) {
        setLocationOpen(false);
      }
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setSearchOpen(false);
      }
      if (sbDropRef.current && !sbDropRef.current.contains(e.target as Node)) {
        setSbDropOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // ── Live search ────────────────────────────────────────────────────────────
  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    if (!query.trim()) { setSearchResults([]); setSearchOpen(false); return; }
    setSearchLoading(true);
    searchTimer.current = setTimeout(async () => {
      try {
        const res = await searchAds({ q: query.trim(), page: 1 });
        setSearchResults(res.data.slice(0, 8));
        setSearchOpen(true);
      } catch { /* ignore */ } finally {
        setSearchLoading(false);
      }
    }, 350);
    return () => { if (searchTimer.current) clearTimeout(searchTimer.current); };
  }, [query]);

  // ── Feed load ──────────────────────────────────────────────────────────────
  const loadAds = useCallback(async (filters: AdsFilters, reset = true) => {
    if (reset) setAdsLoading(true); else setLoadingMore(true);
    try {
      const res = await fetchAds(filters);
      setAds(prev => reset ? res.data : [...prev, ...res.data]);
      setCurrentPage(res.meta?.current_page ?? 1);
      setLastPage(res.meta?.last_page ?? 1);
      setTotal(res.meta?.total ?? res.data.length);
    } catch { /* silent */ } finally {
      setAdsLoading(false);
      setLoadingMore(false);
    }
  }, []);

  useEffect(() => {
    loadAds({
      sort,
      city_id:   selectedCity?.id,
      region_id: selectedCity ? undefined : selectedRegion?.id,
      category_id: selectedCategory?.id,
      page: 1,
    }, true);
  }, [sort, selectedCity, selectedRegion, selectedCategory, loadAds]);

  const handleLoadMore = () => {
    if (currentPage >= lastPage) return;
    loadAds({
      sort,
      city_id:   selectedCity?.id,
      region_id: selectedCity ? undefined : selectedRegion?.id,
      category_id: selectedCategory?.id,
      page: currentPage + 1,
    }, false);
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSearchOpen(false);
    if (query.trim()) window.location.href = `/ar/search?q=${encodeURIComponent(query.trim())}`;
  };

  const locationLabel = selectedCity
    ? selectedCity.name_ar
    : selectedRegion
      ? selectedRegion.name_ar
      : 'كل المدن';

  return (
    <>
      <Header />
      <CategoryTabs />

      {/* ── Search hero bar ────────────────────────────────────────────── */}
      <div className={styles.heroBar} dir="rtl">
        <div className={styles.heroInner}>

          {/* Location & Near Me Group */}
          <div className={styles.locGroup}>
            {/* Location dropdown — flat searchable city list */}
            <div className={styles.locWrap} ref={locationRef}>
              <button
              id="location-dropdown-btn"
              className={styles.locBtn}
              onClick={() => { setLocationOpen(o => !o); setCitySearch(''); }}
            >
              <span className={styles.locIcon}>📍</span>
              <span className={styles.locLabel}>{locationLabel}</span>
              <span className={`${styles.locChevron} ${locationOpen ? styles.locChevronOpen : ''}`}>▾</span>
            </button>

            {locationOpen && (
              <div className={styles.locDropdown}>
                {/* Search input */}
                <div className={styles.locSearchWrap}>
                  <span className={styles.locSearchIcon}>🔍</span>
                  <input
                    className={styles.locSearchInput}
                    placeholder="ابحث عن مدينة..."
                    value={citySearch}
                    onChange={e => setCitySearch(e.target.value)}
                    autoFocus
                    dir="rtl"
                  />
                  {citySearch && (
                    <button className={styles.locSearchClear} onClick={() => setCitySearch('')}>✕</button>
                  )}
                </div>

                {/* City list */}
                <div className={styles.locScrollable}>
                  {/* "All cities" option */}
                  {!citySearch && (
                    <button
                      className={`${styles.locItem} ${!selectedCity ? styles.locItemActive : ''}`}
                      onClick={() => { setSelectedCity(null); setSelectedRegion(null); setLocationOpen(false); }}
                    >
                      🌍 كل المدن
                    </button>
                  )}

                  {citiesLoading && [1,2,3,4,5,6].map(i => (
                    <div key={i} className={styles.locSkeleton} />
                  ))}

                  {!citiesLoading && (() => {
                    const q = citySearch.trim();
                    const filtered = q
                      ? allCities.filter(c =>
                          c.name_ar.includes(q) || c.name_en?.toLowerCase().includes(q.toLowerCase())
                        )
                      : allCities;
                    
                    if (filtered.length === 0) return (
                      <div className={styles.locEmpty}>لا توجد مدينة بهذا الاسم</div>
                    );

                    return filtered.map(c => (
                      <button
                        key={c.id}
                        className={`${styles.locItem} ${selectedCity?.id === c.id ? styles.locItemActive : ''}`}
                        onClick={() => {
                          setSelectedCity(c);
                          setSelectedRegion(c.region ? { id: c.region.id, name_ar: c.region.name_ar, name_en: c.region.name_en, slug: c.region.slug, sort_order: 0, cities_count: 0 } : null);
                          setLocationOpen(false);
                          setCitySearch('');
                        }}
                      >
                        <span className={styles.locCityName}>{c.name_ar}</span>
                        {c.region && <span className={styles.locCityRegion}>{c.region.name_ar}</span>}
                      </button>
                    ));
                  })()}
                </div>
              </div>
            )}
            </div>

            {/* Near Me Toggle */}
            <label className={`${styles.nearMeToggle} ${nearMe ? styles.nearMeActive : ''}`}>
              <input type="checkbox" checked={nearMe} onChange={e => setNearMe(e.target.checked)} className={styles.srOnly} />
              القريب مني
            </label>
          </div>


        </div>
      </div>

      {/* ── Main layout ────────────────────────────────────────────────── */}
      <main className={styles.main} dir="rtl">
        <div className={styles.layout}>

          {/* ── Sidebar (desktop) ──────────────────────────────────────── */}
          <aside className={styles.sidebar}>

            {/* ① Category custom searchable dropdown */}
            <div className={`${styles.sbCard} ${styles.sbCardOverflowVisible}`}>
              {/* Custom dropdown trigger */}
              <div className={styles.sbDropWrap} ref={sbDropRef}>
                <button
                  id="sidebar-category-btn"
                  className={styles.sbDropTrigger}
                  onClick={() => { setSbDropOpen(o => !o); setCategorySearch(''); }}
                  type="button"
                >
                  <span className={styles.sbDropValue}>
                    {selectedCategory ? selectedCategory.name_ar : 'كل الأقسام'}
                  </span>
                  <span className={`${styles.sbDropArrow} ${sbDropOpen ? styles.sbDropArrowOpen : ''}`}>▾</span>
                </button>

                {sbDropOpen && (
                  <div className={styles.sbDropPanel}>
                    {/* Search input inside dropdown */}
                    <div className={styles.sbDropSearch}>
                      <span className={styles.sbDropSearchIcon}>🔍</span>
                      <input
                        autoFocus
                        type="text"
                        className={styles.sbDropSearchInput}
                        placeholder="ابحث عن قسم..."
                        value={categorySearch}
                        onChange={e => setCategorySearch(e.target.value)}
                      />
                      {categorySearch && (
                        <button className={styles.sbDropSearchClear} onClick={() => setCategorySearch('')}>✕</button>
                      )}
                    </div>

                    {/* All categories option */}
                    <div className={styles.sbDropList}>
                      <button
                        className={`${styles.sbDropItem} ${!selectedCategory ? styles.sbDropItemActive : ''}`}
                        onClick={() => { setSelectedCategory(null); setSbDropOpen(false); }}
                      >
                        📦 كل الأقسام
                      </button>

                      {categories.length === 0 && [1,2,3,4,5].map(i => (
                        <div key={i} className={styles.sbDropSkeleton} />
                      ))}

                      {categories.length > 0 && (
                        categories
                          .filter(c => !categorySearch || c.name_ar.includes(categorySearch))
                          .map(c => (
                            <button
                              key={c.id}
                              id={`sidebar-category-${c.slug}`}
                              className={`${styles.sbDropItem} ${selectedCategory?.id === c.id ? styles.sbDropItemActive : ''}`}
                              onClick={() => {
                                setSelectedCategory(c);
                                setSbDropOpen(false);
                                setCategorySearch('');
                              }}
                            >
                              <span>{c.icon ?? '📁'} {c.name_ar}</span>
                            </button>
                          ))
                      )}

                      {categories.length > 0 && categorySearch && categories.filter(c => c.name_ar.includes(categorySearch)).length === 0 && (
                        <div className={styles.sbDropEmpty}>لا توجد نتائج</div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* ② +تصفية collapsible */}
            <div className={styles.sbCard}>
              <button
                className={styles.sbFilterToggle}
                onClick={() => setFilterOpen(o => !o)}
              >
                <span className={styles.sbFilterIcon}>{filterOpen ? '−' : '+'}</span>
                <span>تصفية</span>
              </button>
              {filterOpen && (
                <div className={styles.sbFilterBody}>
                  {/* Sort */}
                  <div className={styles.sbFilterSection}>
                    <div className={styles.sbFilterLabel}>الترتيب</div>
                    {SORT_OPTS.map(opt => (
                      <label key={opt.val} className={styles.radioItem}>
                        <input
                          type="radio"
                          name="sort-sidebar"
                          className={styles.radio}
                          checked={sort === opt.val}
                          onChange={() => setSort(opt.val)}
                        />
                        {opt.label}
                      </label>
                    ))}
                  </div>
                  {/* Condition */}
                  <div className={styles.sbFilterSection}>
                    <div className={styles.sbFilterLabel}>المسافة</div>
                    <label className={styles.radioItem}>
                      <input type="radio" name="condition-sb" className={styles.radio} checked={!nearMe} onChange={() => setNearMe(false)} />
                      الكل
                    </label>
                    <label className={styles.radioItem}>
                      <input type="radio" name="condition-sb" className={styles.radio} checked={nearMe} onChange={() => setNearMe(true)} />
                      القريب مني
                    </label>
                  </div>
                  {/* Cities from allCities filtered by selectedRegion */}
                  {selectedRegion && (
                    <div className={styles.sbFilterSection}>
                      <div className={styles.sbFilterLabel}>المدن</div>
                      <button
                        className={`${styles.sbCityBtn} ${!selectedCity ? styles.sbCityActive : ''}`}
                        onClick={() => setSelectedCity(null)}
                      >
                        كل {selectedRegion.name_ar}
                      </button>
                      {citiesLoading && [1,2,3].map(i => <div key={i} className={styles.sbCitySkeleton} />)}
                      {!citiesLoading && allCities
                        .filter(c => c.region?.slug === selectedRegion.slug)
                        .map(c => (
                          <button
                            key={c.id}
                            id={`sidebar-city-${c.slug}`}
                            className={`${styles.sbCityBtn} ${selectedCity?.id === c.id ? styles.sbCityActive : ''}`}
                            onClick={() => setSelectedCity(c)}
                          >
                            {c.name_ar}
                          </button>
                        ))
                      }
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* ③ تنقل السريع — vertical list */}
            {categories.length > 0 && (
              <div className={styles.sbCardFlat}>
                <h3 className={styles.sbNavTitleFlat}>تنقل السريع</h3>
                <div className={styles.sbNavListFlat}>
                  {(showMoreCats ? categories : categories.slice(0, 6)).map(cat => (
                    <Link
                      key={cat.slug}
                      href={`/ar/categories/${cat.slug}`}
                      id={`nav-cat-${cat.slug}`}
                      className={styles.sbNavItemFlat}
                      title={cat.name_ar}
                    >
                      <span className={styles.sbNavEmojiFlat}>{cat.icon || '📁'}</span>
                      <span className={styles.sbNavLabelFlat}>{cat.name_ar}</span>
                      <span className={styles.sbNavArrowFlat}>←</span>
                    </Link>
                  ))}
                </div>

                {categories.length > 6 && (
                  <button
                    className={styles.sbShowMoreFlat}
                    onClick={() => setShowMoreCats(s => !s)}
                  >
                    {showMoreCats ? 'عرض أقل' : 'عرض المزيد'}
                    <span className={styles.sbShowMoreIconFlat}>{showMoreCats ? '▲' : '▾'}</span>
                  </button>
                )}
              </div>
            )}
          </aside>

          {/* ── Feed ───────────────────────────────────────────────────── */}
          <div className={styles.feed}>



            {/* Active filter chip */}
            {(selectedRegion || selectedCity) && (
              <div className={styles.activeBreadcrumb}>
                <span className={styles.breadcrumbText}>
                  📍 {selectedCity ? selectedCity.name_ar : selectedRegion?.name_ar}
                </span>
                <button
                  className={styles.breadcrumbClear}
                  onClick={() => { setSelectedRegion(null); setSelectedCity(null); }}
                >
                  ✕ إلغاء
                </button>
              </div>
            )}


            {/* Banner */}
            <BannerCarousel position="home_top" />

            {/* Skeletons */}
            {adsLoading && (
              <div className={viewMode === 'list' ? styles.adList : styles.adGrid}>
                {Array.from({ length: 8 }).map((_, i) => (
                  viewMode === 'list'
                    ? <div key={i} className={styles.adListSkeleton} />
                    : <div key={i} className={styles.adCardSkeleton} />
                ))}
              </div>
            )}

            {/* Results */}
            {!adsLoading && ads.length > 0 && (
              viewMode === 'list'
                ? (
                  <div className={styles.adList}>
                    {ads.map(ad => <AdListRow key={ad.id} ad={ad} />)}
                  </div>
                ) : (
                  <div className={styles.adGrid}>
                    {ads.map(ad => <AdCard key={ad.id} ad={ad} />)}
                  </div>
                )
            )}

            {/* Empty */}
            {!adsLoading && ads.length === 0 && (
              <div className={styles.emptyFeed}>
                <span className={styles.emptyFeedIcon}>🔍</span>
                <h3>لا توجد إعلانات</h3>
                <p>لم يتم العثور على إعلانات بالفلاتر المحددة. جرّب تغيير المدينة أو التصنيف.</p>
                <Link href="/ar/post-ad" className={styles.emptyFeedCta}>+ نشر أول إعلان</Link>
              </div>
            )}

            {/* Load more */}
            {!adsLoading && currentPage < lastPage && (
              <div className={styles.loadMore}>
                <button className={styles.loadMoreBtn} onClick={handleLoadMore} disabled={loadingMore}>
                  {loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'}
                </button>
              </div>
            )}
          </div>
        </div>
      </main>

      <Footer />

      {/* ── Mobile Bottom Nav ───────────────────────────────────────── */}
      <BottomNav
        onCategoriesOpen={() => setDrawerOpen(true)}
        onAuthOpen={() => setAuthOpen(true)}
      />

      {/* ── Mobile Categories & Filter Drawer ──────────────────────── */}
      <MobileDrawer
        isOpen={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        categories={categories}
        selectedCategory={selectedCategory}
        onSelectCategory={setSelectedCategory}
        sort={sort}
        onSortChange={setSort}
        nearMe={nearMe}
        onNearMeChange={setNearMe}
      />

      {/* ── Auth Modal ─────────────────────────────────────────────── */}
      <AuthModal isOpen={authOpen} onClose={() => setAuthOpen(false)} />
    </>
  );
}

// ── Ad List Row (Haraj-style) ─────────────────────────────────────────────────
function AdListRow({ ad }: { ad: AdListItem }) {
  const priceText = ad.is_free
    ? 'مجانية'
    : ad.price
      ? `${Number(ad.price).toLocaleString('ar-SA')}`
      : 'على السوم';

  // Demo image fallback based on ad.id modulo
  const DEMO_IMAGES = ['/images/car.jpg', '/images/fridge.jpeg', '/images/labtop.webp', '/images/mobile.jpeg'];
  const imgSrc = ad.primary_image?.thumbnail_url || DEMO_IMAGES[ad.id % DEMO_IMAGES.length];

  return (
    <Link href={`/ar/ads/${ad.id}`} className={styles.adListRowHaraj}>
      {/* 1) Info on Right Side (RTL Start) */}
      <div className={styles.adListInfoRight}>
        <h3 className={styles.adListTitleHaraj}>{ad.title}</h3>
        
        <div className={styles.adListBottomRow}>
          <div className={styles.adListMetaGroup}>
            <div className={styles.adListMetaItem}>
              <span className={styles.metaText}>{ad.city?.name_ar || 'السعودية'}</span>
              <span className={styles.metaIcon}>📍</span>
            </div>
            <div className={styles.adListMetaItem} dir="rtl">
              <span className={styles.metaText}>{relativeTime(ad.published_at ?? ad.created_at)}</span>
              <span className={styles.metaIcon}>🕐</span>
            </div>
          </div>

          <div className={styles.adListUserGroup}>
            <span className={styles.metaText}>{ad.user?.name || `user_${ad.user_id}`}</span>
            <div className={styles.userAvatarSm}>
              {(ad.user?.name || 'م').charAt(0).toUpperCase()}
            </div>
          </div>
        </div>
      </div>

      {/* 2) Price beside the image */}
      <div className={styles.adListPriceBox}>
        {priceText} {ad.price && !ad.is_free && <span className={styles.currencyLabel}>ر.س</span>}
      </div>

      {/* 3) Image on Left Side (RTL End) */}
      <div className={styles.adListMediaLeft}>
        <div className={styles.adListImgWrapper}>
          <img src={imgSrc} alt={ad.title} className={styles.adListImgReal} />
          {ad.is_boosted && <span className={styles.boostBadgeTop}>⭐ مميز</span>}
        </div>
      </div>
    </Link>
  );
}

// ── Ad Grid Card ──────────────────────────────────────────────────────────────
function AdCard({ ad }: { ad: AdListItem }) {
  const priceText = ad.is_free
    ? 'مجاني'
    : ad.price
      ? `${Number(ad.price).toLocaleString('ar-SA')} ر.س`
      : 'السعر عند التواصل';

  return (
    <Link href={`/ar/ads/${ad.id}`} className={styles.adCard}>
      <div className={styles.adImg}>
        {ad.primary_image ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={ad.primary_image.thumbnail_url} alt={ad.title} className={styles.adImgReal} />
        ) : (
          <div className={styles.adImgPlaceholder}>
            <span>{ad.category?.icon ?? '📦'}</span>
            <small>لا توجد صورة</small>
          </div>
        )}
        {ad.is_boosted && <span className={styles.boostChip}>⚡ مميز</span>}
      </div>
      <div className={styles.adBody}>
        <h3 className={styles.adTitle}>{ad.title}</h3>
        <p className={styles.adPrice}>{priceText}
          {ad.is_negotiable && !ad.is_free && <span className={styles.negText}> · قابل للتفاوض</span>}
        </p>
        <div className={styles.adMeta}>
          <span className={styles.adCity}>📍 {ad.city?.name_ar ?? '—'}</span>
          <span className={styles.adTime}>{relativeTime(ad.published_at ?? ad.created_at)}</span>
        </div>
      </div>
    </Link>
  );
}
