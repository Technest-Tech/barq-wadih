'use client';

import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { fetchCategories, type Category } from '@/lib/api/categories';
import styles from './CategoryTabs.module.css';

// ── Fallback static data (shown if API fails) ─────────────────────────────────
const FALLBACK_CATEGORIES: Pick<Category, 'id' | 'icon' | 'name_ar' | 'slug'>[] = [
  { id: 0,  icon: '🚗', name_ar: 'سيارات',        slug: 'cars'           },
  { id: 2,  icon: '📱', name_ar: 'إلكترونيات',     slug: 'electronics'   },
  { id: 3,  icon: '🛋️', name_ar: 'أثاث ومفروشات', slug: 'furniture'     },
  { id: 4,  icon: '💼', name_ar: 'وظائف',           slug: 'jobs'          },
  { id: 5,  icon: '🔧', name_ar: 'خدمات',           slug: 'services'      },
  { id: 6,  icon: '👗', name_ar: 'أزياء وملابس',   slug: 'fashion'       },
  { id: 7,  icon: '⚽', name_ar: 'رياضة وترفيه',   slug: 'sports-leisure'},
  { id: 8,  icon: '📚', name_ar: 'كتب ومجلات',     slug: 'books-magazines'},
  { id: 9,  icon: '🧸', name_ar: 'ألعاب وأطفال',   slug: 'toys-kids'     },
  { id: 10, icon: '🐕', name_ar: 'حيوانات',         slug: 'animals'       },
  { id: 11, icon: '📦', name_ar: 'أخرى',            slug: 'other'         },
];

export default function CategoryTabs() {
  const [categories, setCategories] = useState<typeof FALLBACK_CATEGORIES>([]);
  const [loading, setLoading] = useState(true);
  const [activeSlug, setActiveSlug] = useState<string>('all');
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    fetchCategories()
      .then((data) => {
        setCategories(data.map((c) => ({
          id:      c.id,
          icon:    c.icon ?? '📦',
          name_ar: c.name_ar,
          slug:    c.slug,
        })));
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
          href="/ar"
          id="category-tab-all"
          className={`${styles.tab} ${activeSlug === 'all' ? styles.tabActive : ''}`}
          onClick={() => setActiveSlug('all')}
        >
          <span className={styles.tabIcon}>🏠</span>
          <span className={styles.tabName}>الكل</span>
        </Link>

        {/* Skeleton tabs while loading */}
        {loading && Array.from({ length: 8 }).map((_, i) => (
          <div key={`skel-${i}`} className={`${styles.tab} ${styles.skeleton}`}>
            <span className={styles.skeletonIcon} />
            <span className={styles.skeletonLabel} />
          </div>
        ))}

        {/* Real category tabs */}
        {!loading && categories.map((cat) => (
          <Link
            key={cat.id}
            href={`/ar/categories/${cat.slug}`}
            id={`category-tab-${cat.slug}`}
            className={`${styles.tab} ${activeSlug === cat.slug ? styles.tabActive : ''}`}
            onClick={() => setActiveSlug(cat.slug)}
          >
            <span className={styles.tabIcon}>{cat.icon}</span>
            <span className={styles.tabName}>{cat.name_ar}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
