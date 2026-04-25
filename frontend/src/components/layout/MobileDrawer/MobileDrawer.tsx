'use client';

import Link from 'next/link';
import { X, SlidersHorizontal } from 'lucide-react';
import { type Category } from '@/lib/api/categories';
import { type AdsFilters } from '@/lib/api/ads';
import styles from './MobileDrawer.module.css';

interface MobileDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  categories: Category[];
  selectedCategory: Category | null;
  onSelectCategory: (cat: Category | null) => void;
  sort: AdsFilters['sort'];
  onSortChange: (sort: AdsFilters['sort']) => void;
  nearMe: boolean;
  onNearMeChange: (v: boolean) => void;
}

const SORT_OPTS: { val: AdsFilters['sort']; label: string }[] = [
  { val: 'newest',     label: '⬇ الأحدث' },
  { val: 'price_asc',  label: '⬆ أقل سعر' },
  { val: 'price_desc', label: '⬇ أعلى سعر' },
];

export default function MobileDrawer({
  isOpen,
  onClose,
  categories,
  selectedCategory,
  onSelectCategory,
  sort,
  onSortChange,
  nearMe,
  onNearMeChange,
}: MobileDrawerProps) {
  if (!isOpen) return null;

  return (
    <>
      {/* Overlay */}
      <div className={styles.overlay} onClick={onClose} />

      {/* Drawer */}
      <div className={`${styles.drawer} ${isOpen ? styles.drawerOpen : ''}`} dir="rtl">
        {/* Handle */}
        <div className={styles.handle} />

        {/* Header */}
        <div className={styles.header}>
          <h2 className={styles.title}>الأقسام والتصفية</h2>
          <button className={styles.closeBtn} onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        {/* Categories Grid */}
        <div className={styles.section}>
          <h3 className={styles.sectionTitle}>الأقسام</h3>
          <div className={styles.catGrid}>
            {/* All categories */}
            <button
              className={`${styles.catItem} ${!selectedCategory ? styles.catItemActive : ''}`}
              onClick={() => { onSelectCategory(null); onClose(); }}
            >
              <span className={styles.catIcon}>📦</span>
              <span className={styles.catLabel}>الكل</span>
            </button>

            {categories.map(cat => (
              <Link
                key={cat.id}
                href={`/ar/categories/${cat.slug}`}
                className={`${styles.catItem} ${selectedCategory?.id === cat.id ? styles.catItemActive : ''}`}
                onClick={() => { onSelectCategory(cat); onClose(); }}
              >
                <span className={styles.catIcon}>{cat.icon || '📁'}</span>
                <span className={styles.catLabel}>{cat.name_ar}</span>
              </Link>
            ))}
          </div>
        </div>

        {/* Filters */}
        <div className={styles.section}>
          <h3 className={styles.sectionTitle}>
            <SlidersHorizontal size={16} />
            التصفية
          </h3>

          {/* Sort */}
          <div className={styles.filterGroup}>
            <div className={styles.filterLabel}>الترتيب</div>
            <div className={styles.pillRow}>
              {SORT_OPTS.map(opt => (
                <button
                  key={opt.val}
                  className={`${styles.filterPill} ${sort === opt.val ? styles.filterPillActive : ''}`}
                  onClick={() => onSortChange(opt.val)}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>

          {/* Near Me */}
          <div className={styles.filterGroup}>
            <div className={styles.filterLabel}>المسافة</div>
            <div className={styles.pillRow}>
              <button
                className={`${styles.filterPill} ${!nearMe ? styles.filterPillActive : ''}`}
                onClick={() => onNearMeChange(false)}
              >
                الكل
              </button>
              <button
                className={`${styles.filterPill} ${nearMe ? styles.filterPillActive : ''}`}
                onClick={() => onNearMeChange(true)}
              >
                📍 القريب مني
              </button>
            </div>
          </div>
        </div>

        {/* Apply button */}
        <div className={styles.applyWrap}>
          <button className={styles.applyBtn} onClick={onClose}>
            عرض النتائج
          </button>
        </div>
      </div>
    </>
  );
}
