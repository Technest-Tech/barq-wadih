'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import Link from 'next/link';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import { List, LayoutGrid } from 'lucide-react';
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
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return 'الآن';
  if (diffMin < 60) return `منذ ${diffMin} د`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `منذ ${diffHr} س`;
  return `منذ ${Math.floor(diffHr / 24)} ي`;
}

const SORT_OPTS: { val: AdsFilters['sort']; label: string }[] = [
  { val: 'newest', label: '⬇ الأحدث' },
  { val: 'price_asc', label: '⬆ أقل سعر' },
  { val: 'price_desc', label: '⬇ أعلى سعر' },
];

type SelectedRegion = Pick<Region, 'id' | 'name_ar' | 'name_en' | 'slug'>;

// Haversine distance in km between two lat/lng points.
function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function findNearestCity(cities: City[], lat: number, lng: number): City | null {
  let best: City | null = null;
  let bestDist = Infinity;
  for (const c of cities) {
    if (c.latitude == null || c.longitude == null) continue;
    const d = haversineKm(lat, lng, c.latitude, c.longitude);
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }
  return best;
}

// ── Page ──────────────────────────────────────────────────────────────────────
export default function HomePage() {
  // Location — flat searchable city list
  const [allCities, setAllCities] = useState<City[]>([]);
  const [citySearch, setCitySearch] = useState('');
  const [selectedCity, setSelectedCity] = useState<City | null>(null);
  const [citiesLoading, setCitiesLoading] = useState(true);
  const [locationOpen, setLocationOpen] = useState(false);
  // Keep selectedRegion for feed filtering compatibility
  const [selectedRegion, setSelectedRegion] = useState<SelectedRegion | null>(null);
  const locationRef = useRef<HTMLDivElement>(null);

  const router = useRouter();
  const params = useParams<{ locale?: string }>();
  const searchParams = useSearchParams();
  const locale = params?.locale ?? 'ar';
  const urlQuery = (searchParams?.get('q') ?? '').trim();
  const urlCategory = (searchParams?.get('category') ?? '').trim();

  // Feed
  const [ads, setAds] = useState<AdListItem[]>([]);
  const [adsLoading, setAdsLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [sort, setSort] = useState<AdsFilters['sort']>('newest');
  const [currentPage, setCurrentPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [viewMode, setViewMode] = useState<'list' | 'grid'>('list');
  const [nearMe, setNearMe] = useState(false);
  const [feedError, setFeedError] = useState(false);
  const [citiesError, setCitiesError] = useState(false);
  const [geoError, setGeoError] = useState<string | null>(null);
  const [geoLoading, setGeoLoading] = useState(false);

  // Categories (quick nav & dropdown)
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<Category | null>(null);
  const [showMoreCats, setShowMoreCats] = useState(false);
  const [filterOpen, setFilterOpen] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [authOpen, setAuthOpen] = useState(false);

  // Sidebar searchable category dropdown
  const [sbDropOpen, setSbDropOpen] = useState(false);
  const [categorySearch, setCategorySearch] = useState('');
  const sbDropRef = useRef<HTMLDivElement>(null);

  // ── Boot ───────────────────────────────────────────────────────────────────
  const loadCities = useCallback(() => {
    setCitiesLoading(true);
    setCitiesError(false);
    fetchAllCities()
      .then(setAllCities)
      .catch((e) => {
        console.error(e);
        setCitiesError(true);
      })
      .finally(() => setCitiesLoading(false));
  }, []);

  useEffect(() => {
    loadCities();
    fetchCategories().then(setCategories).catch(console.error);
  }, [loadCities]);

  // Sync ?category= URL param → selectedCategory once categories list is loaded
  useEffect(() => {
    if (!categories.length) return;
    if (!urlCategory) {
      setSelectedCategory(null);
      return;
    }
    const match = categories.find((c) => c.slug === urlCategory) ?? null;
    setSelectedCategory(match);
  }, [urlCategory, categories]);

  // Close dropdowns on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (locationRef.current && !locationRef.current.contains(e.target as Node)) {
        setLocationOpen(false);
      }
      if (sbDropRef.current && !sbDropRef.current.contains(e.target as Node)) {
        setSbDropOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // ── Feed load ──────────────────────────────────────────────────────────────
  // Uses searchAds when q is present (search term came from header bar / ?q=),
  // otherwise the standard fetchAds feed.
  const loadAds = useCallback(async (filters: AdsFilters, reset = true) => {
    if (reset) setAdsLoading(true);
    else setLoadingMore(true);
    setFeedError(false);
    try {
      const res =
        filters.q && filters.q.trim().length > 0
          ? await searchAds(filters)
          : await fetchAds(filters);
      setAds((prev) => (reset ? res.data : [...prev, ...res.data]));
      setCurrentPage(res.meta?.current_page ?? 1);
      setLastPage(res.meta?.last_page ?? 1);
      setTotal(res.meta?.total ?? res.data.length);
    } catch (e) {
      console.error(e);
      if (reset) setAds([]);
      setFeedError(true);
    } finally {
      setAdsLoading(false);
      setLoadingMore(false);
    }
  }, []);

  // ── Near-me: geolocation → nearest city ────────────────────────────────────
  const handleNearMeToggle = useCallback(
    (next: boolean) => {
      setGeoError(null);
      if (!next) {
        setNearMe(false);
        return;
      }
      if (typeof navigator === 'undefined' || !navigator.geolocation) {
        setGeoError('المتصفح لا يدعم تحديد الموقع');
        return;
      }
      if (allCities.length === 0) {
        setGeoError('لم يتم تحميل المدن بعد');
        return;
      }
      setGeoLoading(true);
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const nearest = findNearestCity(allCities, pos.coords.latitude, pos.coords.longitude);
          setGeoLoading(false);
          if (!nearest) {
            setGeoError('تعذّر إيجاد مدينة قريبة');
            return;
          }
          setSelectedCity(nearest);
          setSelectedRegion(nearest.region ?? null);
          setNearMe(true);
        },
        (err) => {
          setGeoLoading(false);
          setGeoError(
            err.code === err.PERMISSION_DENIED ? 'يجب السماح بالوصول للموقع' : 'تعذّر تحديد موقعك'
          );
        },
        { enableHighAccuracy: false, timeout: 8000, maximumAge: 5 * 60_000 }
      );
    },
    [allCities]
  );

  const retryLoad = useCallback(() => {
    loadAds(
      {
        sort,
        q: urlQuery || undefined,
        city_id: selectedCity?.id,
        region_id: selectedCity ? undefined : selectedRegion?.id,
        category_id: selectedCategory?.id,
        page: 1,
      },
      true
    );
    if (citiesError) loadCities();
  }, [
    loadAds,
    sort,
    urlQuery,
    selectedCity,
    selectedRegion,
    selectedCategory,
    citiesError,
    loadCities,
  ]);

  useEffect(() => {
    loadAds(
      {
        sort,
        q: urlQuery || undefined,
        city_id: selectedCity?.id,
        region_id: selectedCity ? undefined : selectedRegion?.id,
        category_id: selectedCategory?.id,
        page: 1,
      },
      true
    );
  }, [sort, urlQuery, selectedCity, selectedRegion, selectedCategory, loadAds]);

  const handleLoadMore = () => {
    if (currentPage >= lastPage) return;
    loadAds(
      {
        sort,
        q: urlQuery || undefined,
        city_id: selectedCity?.id,
        region_id: selectedCity ? undefined : selectedRegion?.id,
        category_id: selectedCategory?.id,
        page: currentPage + 1,
      },
      false
    );
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
                onClick={() => {
                  setLocationOpen((o) => !o);
                  setCitySearch('');
                }}
              >
                <span className={styles.locIcon}>📍</span>
                <span className={styles.locLabel}>{locationLabel}</span>
                <span
                  className={`${styles.locChevron} ${locationOpen ? styles.locChevronOpen : ''}`}
                >
                  ▾
                </span>
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
                      onChange={(e) => setCitySearch(e.target.value)}
                      autoFocus
                      dir="rtl"
                    />
                    {citySearch && (
                      <button className={styles.locSearchClear} onClick={() => setCitySearch('')}>
                        ✕
                      </button>
                    )}
                  </div>

                  {/* City list */}
                  <div className={styles.locScrollable}>
                    {/* "All cities" option */}
                    {!citySearch && (
                      <button
                        className={`${styles.locItem} ${!selectedCity ? styles.locItemActive : ''}`}
                        onClick={() => {
                          setSelectedCity(null);
                          setSelectedRegion(null);
                          setLocationOpen(false);
                        }}
                      >
                        🌍 كل المدن
                      </button>
                    )}

                    {citiesLoading &&
                      [1, 2, 3, 4, 5, 6].map((i) => <div key={i} className={styles.locSkeleton} />)}

                    {!citiesLoading &&
                      (() => {
                        const q = citySearch.trim();
                        const filtered = q
                          ? allCities.filter(
                              (c) =>
                                c.name_ar.includes(q) ||
                                c.name_en?.toLowerCase().includes(q.toLowerCase())
                            )
                          : allCities;

                        if (filtered.length === 0)
                          return <div className={styles.locEmpty}>لا توجد مدينة بهذا الاسم</div>;

                        return filtered.map((c) => (
                          <button
                            key={c.id}
                            className={`${styles.locItem} ${selectedCity?.id === c.id ? styles.locItemActive : ''}`}
                            onClick={() => {
                              setSelectedCity(c);
                              setSelectedRegion(c.region ?? null);
                              setLocationOpen(false);
                              setCitySearch('');
                            }}
                          >
                            <span className={styles.locCityName}>{c.name_ar}</span>
                            {c.region && (
                              <span className={styles.locCityRegion}>{c.region.name_ar}</span>
                            )}
                          </button>
                        ));
                      })()}
                  </div>
                </div>
              )}
            </div>

            {/* Near Me Toggle — uses browser geolocation to snap feed to nearest city */}
            <button
              type="button"
              className={`${styles.nearMeToggle} ${nearMe ? styles.nearMeActive : ''}`}
              onClick={() => handleNearMeToggle(!nearMe)}
              disabled={geoLoading || citiesLoading}
              title={geoError ?? 'اعرض إعلانات أقرب مدينة لموقعك'}
            >
              {geoLoading ? '…جارٍ تحديد الموقع' : '📍 القريب مني'}
            </button>
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
                  onClick={() => {
                    setSbDropOpen((o) => !o);
                    setCategorySearch('');
                  }}
                  type="button"
                >
                  <span className={styles.sbDropValue}>
                    {selectedCategory ? selectedCategory.name_ar : 'كل الأقسام'}
                  </span>
                  <span
                    className={`${styles.sbDropArrow} ${sbDropOpen ? styles.sbDropArrowOpen : ''}`}
                  >
                    ▾
                  </span>
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
                        onChange={(e) => setCategorySearch(e.target.value)}
                      />
                      {categorySearch && (
                        <button
                          className={styles.sbDropSearchClear}
                          onClick={() => setCategorySearch('')}
                        >
                          ✕
                        </button>
                      )}
                    </div>

                    {/* All categories option */}
                    <div className={styles.sbDropList}>
                      <button
                        className={`${styles.sbDropItem} ${!selectedCategory ? styles.sbDropItemActive : ''}`}
                        onClick={() => {
                          setSelectedCategory(null);
                          setSbDropOpen(false);
                        }}
                      >
                        📦 كل الأقسام
                      </button>

                      {categories.length === 0 &&
                        [1, 2, 3, 4, 5].map((i) => (
                          <div key={i} className={styles.sbDropSkeleton} />
                        ))}

                      {categories.length > 0 &&
                        categories
                          .filter((c) => !categorySearch || c.name_ar.includes(categorySearch))
                          .map((c) => (
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
                              <CategoryIcon icon={c.icon} name={c.name_ar} />
                              <span>{c.name_ar}</span>
                            </button>
                          ))}

                      {categories.length > 0 &&
                        categorySearch &&
                        categories.filter((c) => c.name_ar.includes(categorySearch)).length ===
                          0 && <div className={styles.sbDropEmpty}>لا توجد نتائج</div>}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* ② +تصفية collapsible */}
            <div className={styles.sbCard}>
              <button className={styles.sbFilterToggle} onClick={() => setFilterOpen((o) => !o)}>
                <span className={styles.sbFilterIcon}>{filterOpen ? '−' : '+'}</span>
                <span>تصفية</span>
              </button>
              {filterOpen && (
                <div className={styles.sbFilterBody}>
                  {/* Sort */}
                  <div className={styles.sbFilterSection}>
                    <div className={styles.sbFilterLabel}>الترتيب</div>
                    {SORT_OPTS.map((opt) => (
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
                  {/* Distance */}
                  <div className={styles.sbFilterSection}>
                    <div className={styles.sbFilterLabel}>المسافة</div>
                    <label className={styles.radioItem}>
                      <input
                        type="radio"
                        name="condition-sb"
                        className={styles.radio}
                        checked={!nearMe}
                        onChange={() => handleNearMeToggle(false)}
                      />
                      الكل
                    </label>
                    <label className={styles.radioItem}>
                      <input
                        type="radio"
                        name="condition-sb"
                        className={styles.radio}
                        checked={nearMe}
                        onChange={() => handleNearMeToggle(true)}
                        disabled={geoLoading || citiesLoading}
                      />
                      القريب مني {geoLoading && '…'}
                    </label>
                    {geoError && <div className={styles.sbFilterError}>{geoError}</div>}
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
                      {citiesLoading &&
                        [1, 2, 3].map((i) => <div key={i} className={styles.sbCitySkeleton} />)}
                      {!citiesLoading &&
                        allCities
                          .filter((c) => c.region?.slug === selectedRegion.slug)
                          .map((c) => (
                            <button
                              key={c.id}
                              id={`sidebar-city-${c.slug}`}
                              className={`${styles.sbCityBtn} ${selectedCity?.id === c.id ? styles.sbCityActive : ''}`}
                              onClick={() => setSelectedCity(c)}
                            >
                              {c.name_ar}
                            </button>
                          ))}
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
                  {(showMoreCats ? categories : categories.slice(0, 6)).map((cat) => {
                    const active = selectedCategory?.id === cat.id;
                    return (
                      <button
                        key={cat.slug}
                        id={`nav-cat-${cat.slug}`}
                        type="button"
                        className={`${styles.sbNavItemFlat} ${active ? styles.sbNavItemFlatActive : ''}`}
                        title={cat.name_ar}
                        onClick={() => setSelectedCategory(active ? null : cat)}
                      >
                        <CategoryIcon
                          icon={cat.icon}
                          name={cat.name_ar}
                          className={styles.sbNavEmojiFlat}
                        />
                        <span className={styles.sbNavLabelFlat}>{cat.name_ar}</span>
                        <span className={styles.sbNavArrowFlat}>{active ? '✓' : '←'}</span>
                      </button>
                    );
                  })}
                </div>

                {categories.length > 6 && (
                  <button
                    className={styles.sbShowMoreFlat}
                    onClick={() => setShowMoreCats((s) => !s)}
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
                  onClick={() => {
                    setSelectedRegion(null);
                    setSelectedCity(null);
                    setNearMe(false);
                  }}
                >
                  ✕ إلغاء
                </button>
              </div>
            )}

            {/* Active search-term chip */}
            {urlQuery && (
              <div className={styles.activeBreadcrumb}>
                <span className={styles.breadcrumbText}>🔎 «{urlQuery}»</span>
                <button
                  className={styles.breadcrumbClear}
                  onClick={() => router.replace(`/${locale}`)}
                >
                  ✕ إلغاء البحث
                </button>
              </div>
            )}

            {/* Active category chip */}
            {selectedCategory && (
              <div className={styles.activeBreadcrumb}>
                <span className={styles.breadcrumbText}>📦 {selectedCategory.name_ar}</span>
                <button
                  className={styles.breadcrumbClear}
                  onClick={() => setSelectedCategory(null)}
                >
                  ✕ إلغاء
                </button>
              </div>
            )}

            {/* Banner */}
            <BannerCarousel position="home_top" />

            {/* Feed header: result count + view-mode toggle */}
            <div className={styles.feedHeader}>
              <div className={styles.feedCount}>
                {!adsLoading && total > 0 && `${total.toLocaleString('ar-SA')} إعلان`}
              </div>
              <div className={styles.viewToggleGroup} role="group" aria-label="نمط العرض">
                <button
                  type="button"
                  className={`${styles.viewToggleBtn} ${viewMode === 'list' ? styles.viewToggleBtnActive : ''}`}
                  onClick={() => setViewMode('list')}
                  aria-pressed={viewMode === 'list'}
                  aria-label="عرض قائمة"
                  title="عرض قائمة"
                >
                  <List size={18} />
                </button>
                <button
                  type="button"
                  className={`${styles.viewToggleBtn} ${viewMode === 'grid' ? styles.viewToggleBtnActive : ''}`}
                  onClick={() => setViewMode('grid')}
                  aria-pressed={viewMode === 'grid'}
                  aria-label="عرض شبكي"
                  title="عرض شبكي"
                >
                  <LayoutGrid size={18} />
                </button>
              </div>
            </div>

            {/* Error banner */}
            {feedError && !adsLoading && (
              <div className={styles.feedError} role="alert">
                <span>تعذّر تحميل الإعلانات. تحقّق من اتصالك ثم حاول مجدداً.</span>
                <button className={styles.feedErrorRetry} onClick={() => retryLoad()}>
                  إعادة المحاولة
                </button>
              </div>
            )}

            {/* Skeletons */}
            {adsLoading && (
              <div className={viewMode === 'list' ? styles.adList : styles.adGrid}>
                {Array.from({ length: 8 }).map((_, i) =>
                  viewMode === 'list' ? (
                    <div key={i} className={styles.adListSkeleton} />
                  ) : (
                    <div key={i} className={styles.adCardSkeleton} />
                  )
                )}
              </div>
            )}

            {/* Results */}
            {!adsLoading &&
              ads.length > 0 &&
              (viewMode === 'list' ? (
                <div className={styles.adList}>
                  {ads.map((ad) => (
                    <AdListRow key={ad.id} ad={ad} locale={locale} />
                  ))}
                </div>
              ) : (
                <div className={styles.adGrid}>
                  {ads.map((ad) => (
                    <AdCard key={ad.id} ad={ad} locale={locale} />
                  ))}
                </div>
              ))}

            {/* Empty */}
            {!adsLoading && ads.length === 0 && (
              <div className={styles.emptyFeed}>
                <span className={styles.emptyFeedIcon}>🔍</span>
                <h3>لا توجد إعلانات</h3>
                <p>لم يتم العثور على إعلانات بالفلاتر المحددة. جرّب تغيير المدينة أو التصنيف.</p>
                <Link href={`/${locale}/post-ad`} className={styles.emptyFeedCta}>
                  + نشر أول إعلان
                </Link>
              </div>
            )}

            {/* Load more */}
            {!adsLoading && currentPage < lastPage && (
              <div className={styles.loadMore}>
                <button
                  className={styles.loadMoreBtn}
                  onClick={handleLoadMore}
                  disabled={loadingMore}
                >
                  {loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'}
                </button>
              </div>
            )}
          </div>
        </div>
      </main>

      <Footer />

      {/* ── Mobile Bottom Nav ───────────────────────────────────────── */}
      <BottomNav onAuthOpen={() => setAuthOpen(true)} />

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
        onNearMeChange={handleNearMeToggle}
      />

      {/* ── Auth Modal ─────────────────────────────────────────────── */}
      <AuthModal isOpen={authOpen} onClose={() => setAuthOpen(false)} />
    </>
  );
}

// ── Category icon: renders <img> for URL icons, emoji text otherwise ──────────
function CategoryIcon({
  icon,
  name,
  className,
}: {
  icon: string | null | undefined;
  name: string;
  className?: string;
}) {
  if (icon?.startsWith('http')) {
    return (
      <img
        src={icon}
        alt={name}
        className={className}
        style={{ width: 24, height: 24, objectFit: 'contain', flexShrink: 0 }}
      />
    );
  }
  return <span className={className}>{icon ?? '📦'}</span>;
}

// ── Ad List Row (Haraj-style) ─────────────────────────────────────────────────
function AdListRow({ ad, locale }: { ad: AdListItem; locale: string }) {
  const priceText = ad.is_free
    ? 'مجانية'
    : ad.price
      ? `${Number(ad.price).toLocaleString('ar-SA')}`
      : 'على السوم';

  return (
    <Link href={`/${locale}/ads/${ad.id}`} className={styles.adListRowHaraj}>
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
              <span className={styles.metaText}>
                {relativeTime(ad.published_at ?? ad.created_at)}
              </span>
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
          {ad.primary_image ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={ad.primary_image.thumbnail_url}
              alt={ad.title}
              className={styles.adListImgReal}
              loading="lazy"
              decoding="async"
            />
          ) : (
            <div className={styles.adImgPlaceholder}>
              <CategoryIcon icon={ad.category?.icon} name={ad.category?.name_ar ?? ''} />
              <small>لا توجد صورة</small>
            </div>
          )}
          {ad.is_boosted && <span className={styles.boostBadgeTop}>⭐ مميز</span>}
        </div>
      </div>
    </Link>
  );
}

// ── Ad Grid Card ──────────────────────────────────────────────────────────────
function AdCard({ ad, locale }: { ad: AdListItem; locale: string }) {
  const priceText = ad.is_free
    ? 'مجاني'
    : ad.price
      ? `${Number(ad.price).toLocaleString('ar-SA')} ر.س`
      : 'السعر عند التواصل';

  return (
    <Link href={`/${locale}/ads/${ad.id}`} className={styles.adCard}>
      <div className={styles.adImg}>
        {ad.primary_image ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={ad.primary_image.thumbnail_url}
            alt={ad.title}
            className={styles.adImgReal}
            loading="lazy"
            decoding="async"
          />
        ) : (
          <div className={styles.adImgPlaceholder}>
            <CategoryIcon icon={ad.category?.icon} name={ad.category?.name_ar ?? ''} />
            <small>لا توجد صورة</small>
          </div>
        )}
        {ad.is_boosted && <span className={styles.boostChip}>⚡ مميز</span>}
      </div>
      <div className={styles.adBody}>
        <h3 className={styles.adTitle}>{ad.title}</h3>
        <p className={styles.adPrice}>
          {priceText}
          {ad.is_negotiable && !ad.is_free && (
            <span className={styles.negText}> · قابل للتفاوض</span>
          )}
        </p>
        <div className={styles.adMeta}>
          <span className={styles.adCity}>📍 {ad.city?.name_ar ?? '—'}</span>
          <span className={styles.adTime}>{relativeTime(ad.published_at ?? ad.created_at)}</span>
        </div>
      </div>
    </Link>
  );
}
