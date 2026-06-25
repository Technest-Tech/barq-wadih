'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useParams, useSearchParams } from 'next/navigation';
import { Car } from 'lucide-react';
import { fetchCategories, type Category } from '@/lib/api/categories';
import styles from './CategoryTabs.module.css';

const LUCIDE_ICONS: Record<string, React.ReactNode> = {
  cars: <Car size={24} strokeWidth={1.5} />,
};

// ── Fallback static data (shown if API fails) ─────────────────────────────────
const FALLBACK_CATEGORIES: Pick<Category, 'id' | 'icon' | 'name_ar' | 'slug'>[] = [
  { id: 0, icon: '🚗', name_ar: 'سيارات', slug: 'cars' },
  { id: 2, icon: '📱', name_ar: 'إلكترونيات', slug: 'electronics' },
  { id: 3, icon: '🛋️', name_ar: 'أثاث ومفروشات', slug: 'furniture' },
  { id: 4, icon: '💼', name_ar: 'وظائف', slug: 'jobs' },
  { id: 5, icon: '🔧', name_ar: 'خدمات', slug: 'services' },
  { id: 6, icon: '👗', name_ar: 'أزياء وملابس', slug: 'fashion' },
  { id: 7, icon: '⚽', name_ar: 'رياضة وترفيه', slug: 'sports-leisure' },
  { id: 8, icon: '📚', name_ar: 'كتب ومجلات', slug: 'books-magazines' },
  { id: 9, icon: '🧸', name_ar: 'ألعاب وأطفال', slug: 'toys-kids' },
  { id: 10, icon: '🐕', name_ar: 'حيوانات', slug: 'animals' },
  { id: 12, icon: '🎣', name_ar: 'صيد ورحلات', slug: 'hunting-trips' },
  { id: 13, icon: '🍽️', name_ar: 'أطعمة ومشروبات', slug: 'food-beverages' },
  { id: 11, icon: '📦', name_ar: 'أخرى', slug: 'other' },
];

export default function CategoryTabs() {
  const [categories, setCategories] = useState<typeof FALLBACK_CATEGORIES>([]);
  const [loading, setLoading] = useState(true);
  const scrollRef = useRef<HTMLDivElement>(null);

  const params = useParams();
  const searchParams = useSearchParams();
  const locale = (params?.locale as string) || 'ar';
  const activeSlug = searchParams?.get('category') ?? 'all';

  useEffect(() => {
    fetchCategories()
      .then((data) => {
        setCategories(
          data.map((c) => ({
            id: c.id,
            icon: c.icon ?? '📦',
            name_ar: c.name_ar,
            slug: c.slug,
          }))
        );
      })
      .catch(() => {
        // Silently fall back to static data
        setCategories(FALLBACK_CATEGORIES);
      })
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className={styles.bar} dir="rtl">
      <div className={styles.track} ref={scrollRef}>
        {/* "All" tab — always first */}
        <Link
          href={`/${locale}`}
          id="category-tab-all"
          className={`${styles.tab} ${activeSlug === 'all' ? styles.tabActive : ''}`}
        >
          <span className={styles.tabIcon}>🏠</span>
          <span className={styles.tabName}>الكل</span>
        </Link>

        {/* Skeleton tabs while loading */}
        {loading &&
          Array.from({ length: 8 }).map((_, i) => (
            <div key={`skel-${i}`} className={`${styles.tab} ${styles.skeleton}`}>
              <span className={styles.skeletonIcon} />
              <span className={styles.skeletonLabel} />
            </div>
          ))}

        {/* Real category tabs — navigate to home with ?category=slug so home page filters the feed */}
        {!loading &&
          categories.map((cat) => (
            <Link
              key={cat.id}
              href={`/${locale}?category=${cat.slug}`}
              id={`category-tab-${cat.slug}`}
              className={`${styles.tab} ${activeSlug === cat.slug ? styles.tabActive : ''}`}
            >
              {LUCIDE_ICONS[cat.slug] ? (
                <span className={styles.tabIcon}>{LUCIDE_ICONS[cat.slug]}</span>
              ) : cat.icon?.startsWith('http') ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={cat.icon} alt={cat.name_ar} className={styles.tabIconImg} />
              ) : (
                <span className={styles.tabIcon}>{cat.icon ?? '📦'}</span>
              )}
              <span className={styles.tabName}>{cat.name_ar}</span>
            </Link>
          ))}
      </div>
    </div>
  );
}
