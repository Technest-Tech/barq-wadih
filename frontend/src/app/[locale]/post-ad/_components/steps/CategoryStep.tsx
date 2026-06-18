'use client';

import { useEffect, useMemo, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { fetchCategories, type Category, type CategoryChild } from '@/lib/api/categories';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { DealerFeeBadge } from '../shared/DealerFeeBadge';
import { WizardFooter } from '../WizardFooter';

export function CategoryStep() {
  const w = usePostAdWizard();
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetchCategories()
      .then(setCategories)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  // Clear search when navigating between parent/sub levels. Done during render
  // (not in an effect) by comparing against the previous parent category.
  const [prevParent, setPrevParent] = useState(w.parentCategory);
  if (w.parentCategory !== prevParent) {
    setPrevParent(w.parentCategory);
    setSearch('');
  }

  // Per-category flat commission owed after the sale (publishing itself is free).
  const feeFor = (c: CategoryChild | Category): number | null => {
    if ((c as CategoryChild).is_free) return 0;
    const v = (c as unknown as Record<string, number | string | null | undefined>)[
      'deferred_commission_individual'
    ];
    return v === null || v === undefined ? null : Number(v);
  };

  const children = w.parentCategory?.children ?? [];
  const q = search.trim().toLowerCase();

  // Flat search results across ALL parents and their children
  const globalResults = useMemo(() => {
    if (!q || w.parentCategory) return null;
    const results: Array<{ parent: Category; child: CategoryChild | null }> = [];
    for (const parent of categories) {
      const parentMatch = parent.name_ar.toLowerCase().includes(q);
      const matchingChildren = (parent.children ?? []).filter((c) =>
        c.name_ar.toLowerCase().includes(q)
      );
      if (matchingChildren.length > 0) {
        matchingChildren.forEach((child) => results.push({ parent, child }));
      } else if (parentMatch) {
        results.push({ parent, child: null });
      }
    }
    return results;
  }, [q, categories, w.parentCategory]);

  // Filtered list for the subcategory level
  const filteredChildren = useMemo(() => {
    if (!w.parentCategory) return [];
    const source = children.length > 0 ? children : [w.parentCategory as CategoryChild];
    if (!q) return source;
    return source.filter((c) => c.name_ar.toLowerCase().includes(q));
  }, [q, children, w.parentCategory]);

  // Filtered parent categories when no search
  const filteredParents = useMemo(() => {
    if (!q) return categories;
    return categories.filter((c) => c.name_ar.toLowerCase().includes(q));
  }, [q, categories]);

  const isSearching = q.length > 0;

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>📂</span>
        <div>
          <div className={styles.stepTitle}>اختر تصنيف الإعلان</div>
          <div className={styles.stepSub}>
            {w.parentCategory
              ? `داخل: ${w.parentCategory.name_ar}`
              : 'اختر القسم ثم التصنيف الفرعي'}
          </div>
        </div>
      </header>

      {loading ? (
        <div className={styles.loadingWrap}>
          <div className={styles.spinner} />
        </div>
      ) : (
        <>
          {/* Search bar — shown at both levels */}
          <div className={styles.catSearchWrap}>
            <span className={styles.catSearchIcon}>
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </span>
            <input
              className={styles.catSearchInput}
              type="search"
              placeholder={
                w.parentCategory
                  ? `ابحث في ${w.parentCategory.name_ar}...`
                  : 'ابحث في كل التصنيفات...'
              }
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              autoComplete="off"
            />
            {isSearching && (
              <button type="button" className={styles.catSearchClear} onClick={() => setSearch('')}>
                ✕
              </button>
            )}
          </div>

          {/* Subcategory level */}
          {w.parentCategory ? (
            <>
              <button
                type="button"
                className={`${pm.pmBtn} ${pm.pmBtnGhost} ${styles.catBackBtn}`}
                onClick={() => w.setParentCategory(null)}
              >
                <Chevron back /> رجوع للأقسام
              </button>

              {filteredChildren.length === 0 ? (
                <div className={styles.catSearchEmpty}>
                  <div className={styles.catSearchEmptyIcon}>🔍</div>
                  لا توجد نتائج لـ «{search}»
                </div>
              ) : (
                <ul className={styles.catList} role="list">
                  {filteredChildren.map((c) => (
                    <li key={c.id}>
                      <button
                        type="button"
                        className={`${styles.catRow} ${w.category?.id === c.id ? styles.catRowActive : ''}`}
                        onClick={() => w.setCategory(c)}
                      >
                        <span className={styles.catRowName}>{highlightMatch(c.name_ar, q)}</span>
                        <DealerFeeBadge fee={feeFor(c)} />
                        <Chevron />
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </>
          ) : isSearching && globalResults ? (
            /* Global search results across all categories */
            globalResults.length === 0 ? (
              <div className={styles.catSearchEmpty}>
                <div className={styles.catSearchEmptyIcon}>🔍</div>
                لا توجد نتائج لـ «{search}»
              </div>
            ) : (
              <ul className={styles.catList} role="list">
                {globalResults.map(({ parent, child }) => {
                  const target = child ?? (parent as unknown as CategoryChild);
                  return (
                    <li key={`${parent.id}-${child?.id ?? 'p'}`}>
                      <button
                        type="button"
                        className={`${styles.catRow} ${w.category?.id === target.id ? styles.catRowActive : ''}`}
                        onClick={() => {
                          if (child) {
                            w.setParentCategory(parent);
                            w.setCategory(child);
                          } else {
                            w.setParentCategory(parent);
                          }
                        }}
                      >
                        <span className={styles.catRowName}>
                          {highlightMatch(target.name_ar, q)}
                        </span>
                        {child && <span className={styles.catRowBreadcrumb}>{parent.name_ar}</span>}
                        <DealerFeeBadge fee={feeFor(target)} />
                        <Chevron />
                      </button>
                    </li>
                  );
                })}
              </ul>
            )
          ) : (
            /* Normal parent category list */
            <ul className={styles.catList} role="list">
              {filteredParents.map((c) => {
                const childCount = c.children?.length ?? 0;
                return (
                  <li key={c.id}>
                    <button
                      type="button"
                      className={styles.catRow}
                      onClick={() => w.setParentCategory(c)}
                    >
                      <span className={styles.catRowName}>{c.name_ar}</span>
                      {childCount > 0 && (
                        <span className={styles.catRowMeta}>{childCount} تصنيف</span>
                      )}
                      <Chevron />
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </>
      )}

      <WizardFooter />
    </div>
  );
}

/** Wraps matching substring in a <mark> for visual highlight. */
function highlightMatch(text: string, q: string): React.ReactNode {
  if (!q) return text;
  const idx = text.toLowerCase().indexOf(q.toLowerCase());
  if (idx === -1) return text;
  return (
    <>
      {text.slice(0, idx)}
      <mark
        style={{
          background: 'rgba(42,82,152,0.18)',
          color: 'inherit',
          borderRadius: 3,
          padding: '0 1px',
        }}
      >
        {text.slice(idx, idx + q.length)}
      </mark>
      {text.slice(idx + q.length)}
    </>
  );
}

function Chevron({ back = false }: { back?: boolean }) {
  return (
    <svg
      className={`${styles.catChevron} ${back ? styles.catChevronBack : ''}`}
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <polyline points="9 18 15 12 9 6" />
    </svg>
  );
}
