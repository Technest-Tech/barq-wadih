'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useSearchParams, useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { searchAds, type AdListItem, type SearchFilters } from '@/lib/api/ads';
import { fetchCategories, type Category } from '@/lib/api/categories';
import { fetchRegions, fetchCities, type Region, type City } from '@/lib/api/regions';
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

function formatPrice(item: AdListItem): string {
  if (item.is_free) return 'مجاني';
  if (!item.price) return 'تواصل للسعر';
  const n = Number(item.price);
  return `${n.toLocaleString('ar-SA')} ر.س`;
}

const SORT_OPTS = [
  { val: 'relevance', label: '⭐ الأنسب' },
  { val: 'newest', label: '🕒 الأحدث' },
  { val: 'price_asc', label: '💰 أقل سعر' },
  { val: 'price_desc', label: '💰 أعلى سعر' },
] as const;

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SearchPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  // ── URL-synced filter state ───────────────────────────────────────────────
  const [q, setQ] = useState(searchParams.get('q') ?? '');
  const [categoryId, setCategoryId] = useState<number | undefined>(
    searchParams.get('category_id') ? Number(searchParams.get('category_id')) : undefined
  );
  const [cityId, setCityId] = useState<number | undefined>(
    searchParams.get('city_id') ? Number(searchParams.get('city_id')) : undefined
  );
  const [regionId, setRegionId] = useState<number | undefined>(
    searchParams.get('region_id') ? Number(searchParams.get('region_id')) : undefined
  );
  const [priceMin, setPriceMin] = useState(searchParams.get('price_min') ?? '');
  const [priceMax, setPriceMax] = useState(searchParams.get('price_max') ?? '');
  const [sort, setSort] = useState<SearchFilters['sort']>(
    (searchParams.get('sort') as SearchFilters['sort']) ?? 'relevance'
  );

  // ── Results state ─────────────────────────────────────────────────────────
  const [ads, setAds] = useState<AdListItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [page, setPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [firstLoad, setFirstLoad] = useState(true);

  // ── Filter panel data ─────────────────────────────────────────────────────
  const [categories, setCategories] = useState<Category[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [filterOpen, setFilterOpen] = useState(false);

  // ── Debounce ref ──────────────────────────────────────────────────────────
  const debounce = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  // ── Load filter data ──────────────────────────────────────────────────────
  useEffect(() => {
    fetchCategories()
      .then(setCategories)
      .catch(() => {});
    fetchRegions()
      .then(setRegions)
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (regionId) {
      const region = regions.find((r) => r.id === regionId);
      if (region) {
        fetchCities(region.slug)
          .then(setCities)
          .catch(() => {});
      }
    } else {
      setCities([]);
      setCityId(undefined);
    }
  }, [regionId, regions]);

  // ── Push current filters to URL (shareable links) ─────────────────────────
  const pushUrl = useCallback(
    (filters: SearchFilters) => {
      const params = new URLSearchParams();
      if (filters.q) params.set('q', filters.q);
      if (filters.category_id) params.set('category_id', String(filters.category_id));
      if (filters.city_id) params.set('city_id', String(filters.city_id));
      if (filters.region_id) params.set('region_id', String(filters.region_id));
      if (filters.price_min) params.set('price_min', String(filters.price_min));
      if (filters.price_max) params.set('price_max', String(filters.price_max));
      if (filters.sort && filters.sort !== 'relevance') params.set('sort', filters.sort);
      const qs = params.toString();
      router.replace(`${pathname}${qs ? `?${qs}` : ''}`, { scroll: false });
    },
    [pathname, router]
  );

  // ── Fetch results ─────────────────────────────────────────────────────────
  const fetchResults = useCallback(
    async (filters: SearchFilters, pageNum: number, append: boolean) => {
      if (!append) setLoading(true);
      else setLoadingMore(true);
      try {
        const res = await searchAds({ ...filters, page: pageNum });
        if (append) {
          setAds((prev) => [...prev, ...res.data]);
        } else {
          setAds(res.data);
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }
        setTotal(res.meta.total);
        setLastPage(res.meta.last_page);
      } catch {
        // keep existing results
      } finally {
        setLoading(false);
        setLoadingMore(false);
        setFirstLoad(false);
      }
    },
    []
  );

  // ── Auto-search on filter change (debounced) ──────────────────────────────
  const triggerSearch = useCallback(
    (pg = 1) => {
      const filters: SearchFilters = {
        q: q.trim() || undefined,
        category_id: categoryId,
        city_id: cityId,
        region_id: regionId,
        price_min: priceMin ? Number(priceMin) : undefined,
        price_max: priceMax ? Number(priceMax) : undefined,
        sort,
      };
      pushUrl(filters);
      fetchResults(filters, pg, pg > 1);
      setPage(pg);
    },
    [q, categoryId, cityId, regionId, priceMin, priceMax, sort, pushUrl, fetchResults]
  );

  // Initial load from URL params
  useEffect(() => {
    triggerSearch(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Debounce q changes
  const onQChange = (val: string) => {
    setQ(val);
    clearTimeout(debounce.current);
    debounce.current = setTimeout(() => triggerSearch(1), 400);
  };

  // Immediate search on other filter changes
  useEffect(() => {
    if (!firstLoad) triggerSearch(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categoryId, cityId, regionId, sort]);

  const loadMore = () => {
    if (page < lastPage && !loadingMore) {
      const next = page + 1;
      setPage(next);
      triggerSearch(next);
    }
  };

  // Active filter count (excluding q and sort)
  const activeFilters = [categoryId, cityId, priceMin, priceMax].filter(Boolean).length;

  return (
    <>
      <Header />
      <main className={styles.main} dir="rtl">
        {/* ── Search header ─────────────────────────────────────────────── */}
        <div className={styles.searchHeader}>
          <div className={styles.searchBox}>
            <span className={styles.searchIcon}>🔍</span>
            <input
              id="search-input"
              type="search"
              className={styles.searchInput}
              placeholder="ابحث في الإعلانات..."
              value={q}
              onChange={(e) => onQChange(e.target.value)}
              autoFocus
            />
            {q && (
              <button
                className={styles.clearBtn}
                onClick={() => {
                  setQ('');
                  triggerSearch(1);
                }}
                aria-label="مسح البحث"
              >
                ✕
              </button>
            )}
          </div>
        </div>

        <div className={styles.layout}>
          {/* ── Desktop Filter Sidebar ────────────────────────────────────── */}
          <aside className={styles.sidebar}>
            <FilterPanel
              categories={categories}
              regions={regions}
              cities={cities}
              categoryId={categoryId}
              regionId={regionId}
              cityId={cityId}
              priceMin={priceMin}
              priceMax={priceMax}
              sort={sort}
              onCategory={(v) => {
                setCategoryId(v);
              }}
              onRegion={(v) => {
                setRegionId(v);
                setCityId(undefined);
              }}
              onCity={(v) => setCityId(v)}
              onPriceMin={(v) => setPriceMin(v)}
              onPriceMax={(v) => setPriceMax(v)}
              onSort={(v) => setSort(v)}
              onApply={() => triggerSearch(1)}
              onReset={() => {
                setCategoryId(undefined);
                setRegionId(undefined);
                setCityId(undefined);
                setPriceMin('');
                setPriceMax('');
                setSort('relevance');
              }}
            />
          </aside>

          {/* ── Results ──────────────────────────────────────────────────── */}
          <div className={styles.results}>
            {/* Toolbar: result count + sort + mobile filter button */}
            <div className={styles.toolbar}>
              <span className={styles.resultCount}>
                {loading ? 'جارٍ البحث...' : `${total.toLocaleString('ar-SA')} نتيجة`}
                {q && (
                  <>
                    {' '}
                    عن &quot;<strong>{q}</strong>&quot;
                  </>
                )}
              </span>

              <div className={styles.toolbarActions}>
                {/* Mobile filter toggle */}
                <button
                  className={`${styles.filterToggle} ${activeFilters > 0 ? styles.filterToggleActive : ''}`}
                  onClick={() => setFilterOpen((v) => !v)}
                >
                  🎛 فلترة
                  {activeFilters > 0 && <span className={styles.filterBadge}>{activeFilters}</span>}
                </button>

                {/* Sort pills (desktop) */}
                <div className={styles.sortPills}>
                  {SORT_OPTS.map((opt) => (
                    <button
                      key={opt.val}
                      className={`${styles.sortPill} ${sort === opt.val ? styles.sortPillActive : ''}`}
                      onClick={() => setSort(opt.val)}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Mobile filter drawer */}
            {filterOpen && (
              <div className={styles.mobileFilter}>
                <FilterPanel
                  categories={categories}
                  regions={regions}
                  cities={cities}
                  categoryId={categoryId}
                  regionId={regionId}
                  cityId={cityId}
                  priceMin={priceMin}
                  priceMax={priceMax}
                  sort={sort}
                  onCategory={(v) => setCategoryId(v)}
                  onRegion={(v) => {
                    setRegionId(v);
                    setCityId(undefined);
                  }}
                  onCity={(v) => setCityId(v)}
                  onPriceMin={(v) => setPriceMin(v)}
                  onPriceMax={(v) => setPriceMax(v)}
                  onSort={(v) => setSort(v)}
                  onApply={() => {
                    triggerSearch(1);
                    setFilterOpen(false);
                  }}
                  onReset={() => {
                    setCategoryId(undefined);
                    setRegionId(undefined);
                    setCityId(undefined);
                    setPriceMin('');
                    setPriceMax('');
                    setSort('relevance');
                    triggerSearch(1);
                  }}
                />
              </div>
            )}

            {/* Results grid */}
            {loading && !loadingMore ? (
              <div className={styles.grid}>
                {Array.from({ length: 8 }).map((_, i) => (
                  <div key={i} className={styles.skeleton} />
                ))}
              </div>
            ) : ads.length === 0 ? (
              <div className={styles.empty}>
                <span className={styles.emptyIcon}>🔍</span>
                <h2 className={styles.emptyTitle}>
                  {q ? `لا توجد نتائج لـ "${q}"` : 'لا توجد إعلانات بهذه الفلاتر'}
                </h2>
                <p className={styles.emptyHint}>جرّب كلمات مختلفة أو قم بتعديل الفلاتر</p>
                {activeFilters > 0 && (
                  <button
                    className={styles.resetBtn}
                    onClick={() => {
                      setCategoryId(undefined);
                      setRegionId(undefined);
                      setCityId(undefined);
                      setPriceMin('');
                      setPriceMax('');
                      triggerSearch(1);
                    }}
                  >
                    مسح الفلاتر
                  </button>
                )}
              </div>
            ) : (
              <>
                <div className={styles.grid}>
                  {ads.map((ad) => (
                    <AdCard key={ad.id} ad={ad} />
                  ))}
                </div>

                {/* Load more */}
                {page < lastPage && (
                  <div className={styles.loadMoreWrap}>
                    <button
                      className={styles.loadMoreBtn}
                      onClick={loadMore}
                      disabled={loadingMore}
                    >
                      {loadingMore ? <span className={styles.spinner} /> : 'عرض المزيد من النتائج'}
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}

// ── AdCard ────────────────────────────────────────────────────────────────────

function AdCard({ ad }: { ad: AdListItem }) {
  return (
    <Link href={`/ar/ads/${ad.id}`} className={styles.card}>
      <div className={styles.cardImg}>
        {ad.primary_image ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={ad.primary_image.thumbnail_url}
            alt={ad.title}
            loading="lazy"
            decoding="async"
          />
        ) : (
          <div className={styles.cardImgPlaceholder}>
            <span>{ad.category?.icon ?? '📦'}</span>
          </div>
        )}
        {ad.is_boosted && <span className={styles.boostBadge}>⚡ مميز</span>}
      </div>
      <div className={styles.cardBody}>
        <p className={styles.cardTitle}>{ad.title}</p>
        <p className={styles.cardPrice}>{formatPrice(ad)}</p>
        <div className={styles.cardMeta}>
          {ad.city && <span className={styles.cardCity}>📍 {ad.city.name_ar}</span>}
          <span className={styles.cardTime}>{relativeTime(ad.published_at)}</span>
        </div>
      </div>
    </Link>
  );
}

// ── FilterPanel ───────────────────────────────────────────────────────────────

interface FilterPanelProps {
  categories: Category[];
  regions: Region[];
  cities: City[];
  categoryId?: number;
  regionId?: number;
  cityId?: number;
  priceMin: string;
  priceMax: string;
  sort?: SearchFilters['sort'];
  onCategory: (id: number | undefined) => void;
  onRegion: (id: number | undefined) => void;
  onCity: (id: number | undefined) => void;
  onPriceMin: (v: string) => void;
  onPriceMax: (v: string) => void;
  onSort: (v: SearchFilters['sort']) => void;
  onApply: () => void;
  onReset: () => void;
}

function FilterPanel({
  categories,
  regions,
  cities,
  categoryId,
  regionId,
  cityId,
  priceMin,
  priceMax,
  sort,
  onCategory,
  onRegion,
  onCity,
  onPriceMin,
  onPriceMax,
  onSort,
  onApply,
  onReset,
}: FilterPanelProps) {
  return (
    <div className={styles.filterPanel}>
      <div className={styles.filterHeader}>
        <span className={styles.filterTitle}>🎛 الفلاتر</span>
        <button className={styles.filterReset} onClick={onReset}>
          مسح الكل
        </button>
      </div>

      {/* Category */}
      <div className={styles.filterGroup}>
        <label className={styles.filterLabel}>التصنيف</label>
        <div className={styles.categoryChips}>
          <button
            className={`${styles.chip} ${!categoryId ? styles.chipActive : ''}`}
            onClick={() => onCategory(undefined)}
          >
            الكل
          </button>
          {categories.slice(0, 12).map((cat) => (
            <button
              key={cat.id}
              className={`${styles.chip} ${categoryId === cat.id ? styles.chipActive : ''}`}
              onClick={() => onCategory(categoryId === cat.id ? undefined : cat.id)}
            >
              {cat.icon && <span>{cat.icon}</span>} {cat.name_ar}
            </button>
          ))}
        </div>
      </div>

      {/* Region */}
      <div className={styles.filterGroup}>
        <label className={styles.filterLabel}>المنطقة</label>
        <select
          className={styles.filterSelect}
          value={regionId ?? ''}
          onChange={(e) => onRegion(e.target.value ? Number(e.target.value) : undefined)}
        >
          <option value="">كل المناطق</option>
          {regions.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name_ar}
            </option>
          ))}
        </select>
      </div>

      {/* City */}
      {cities.length > 0 && (
        <div className={styles.filterGroup}>
          <label className={styles.filterLabel}>المدينة</label>
          <select
            className={styles.filterSelect}
            value={cityId ?? ''}
            onChange={(e) => onCity(e.target.value ? Number(e.target.value) : undefined)}
          >
            <option value="">كل المدن</option>
            {cities.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name_ar}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* Price Range */}
      <div className={styles.filterGroup}>
        <label className={styles.filterLabel}>نطاق السعر (ر.س)</label>
        <div className={styles.priceRange}>
          <input
            className={styles.priceInput}
            type="number"
            placeholder="من"
            min={0}
            value={priceMin}
            onChange={(e) => onPriceMin(e.target.value)}
          />
          <span className={styles.priceSep}>–</span>
          <input
            className={styles.priceInput}
            type="number"
            placeholder="إلى"
            min={0}
            value={priceMax}
            onChange={(e) => onPriceMax(e.target.value)}
          />
        </div>
      </div>

      {/* Sort (for mobile panel) */}
      <div className={styles.filterGroup}>
        <label className={styles.filterLabel}>الترتيب</label>
        <div className={styles.sortGroup}>
          {SORT_OPTS.map((opt) => (
            <button
              key={opt.val}
              className={`${styles.sortOpt} ${sort === opt.val ? styles.sortOptActive : ''}`}
              onClick={() => onSort(opt.val)}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      <button className={styles.applyBtn} onClick={onApply}>
        تطبيق الفلاتر
      </button>
    </div>
  );
}
