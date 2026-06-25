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
  // Mid-level subcategory being drilled into (e.g. طيور under حيوانات), which
  // exposes a third level (حمام/دجاج/بط). Local to the step — the final pick
  // lives in the store as `category`.
  const [subParent, setSubParent] = useState<CategoryChild | null>(null);

  useEffect(() => {
    fetchCategories()
      .then(setCategories)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  // Clear search when the top-level parent changes (done during render).
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

  const hasChildren = (c: CategoryChild | Category | null | undefined): boolean =>
    !!c && (c.children?.length ?? 0) > 0;

  const q = search.trim().toLowerCase();
  const isSearching = q.length > 0;

  // Children of whichever level we're currently browsing (sub-level if drilled in).
  const currentChildren: CategoryChild[] = subParent
    ? (subParent.children ?? [])
    : (w.parentCategory?.children ?? []);

  // List for the subcategory level (falls back to the parent itself as a leaf).
  const childSource =
    currentChildren.length > 0
      ? currentChildren
      : w.parentCategory
        ? [w.parentCategory as CategoryChild]
        : [];
  const filteredChildren = q
    ? childSource.filter((c) => c.name_ar.toLowerCase().includes(q))
    : childSource;

  const filteredParents = q
    ? categories.filter((c) => c.name_ar.toLowerCase().includes(q))
    : categories;

  // Flatten the whole tree (all levels) for global search with breadcrumbs.
  const allNodes = useMemo(() => {
    const out: Array<{ node: CategoryChild; path: CategoryChild[] }> = [];
    const walk = (nodes: CategoryChild[], path: CategoryChild[]) => {
      for (const n of nodes) {
        out.push({ node: n, path });
        if (n.children?.length) walk(n.children, [...path, n]);
      }
    };
    walk(categories as CategoryChild[], []);
    return out;
  }, [categories]);

  const globalResults = useMemo(() => {
    if (!q || w.parentCategory) return null;
    return allNodes.filter((x) => x.node.name_ar.toLowerCase().includes(q));
  }, [q, allNodes, w.parentCategory]);

  // ── Navigation helpers ──────────────────────────────────────────────────────
  const pickParent = (c: Category) => {
    w.setParentCategory(c);
    setSubParent(null);
  };

  const goBackLevel = () => {
    setSubParent(null);
    if (!subParent) w.setParentCategory(null);
  };

  // Pick a row in the current children list: drill in if it has children, else select.
  const pickChild = (c: CategoryChild) => {
    if (!subParent && hasChildren(c)) {
      setSubParent(c);
      setSearch('');
    } else {
      w.setCategory(c);
    }
  };

  // Pick a node from the flat global search, restoring its full ancestor path.
  const selectFromSearch = (node: CategoryChild, path: CategoryChild[]) => {
    const kids = hasChildren(node);
    if (path.length === 0) {
      w.setParentCategory(node as Category);
      if (!kids) w.setCategory(node);
    } else if (path.length === 1) {
      w.setParentCategory(path[0] as Category);
      if (kids) setSubParent(node);
      else w.setCategory(node);
    } else {
      w.setParentCategory(path[0] as Category);
      setSubParent(path[1]);
      w.setCategory(node);
    }
    setSearch('');
  };

  const headerSub = w.parentCategory
    ? subParent
      ? `${w.parentCategory.name_ar} › ${subParent.name_ar}`
      : `داخل: ${w.parentCategory.name_ar}`
    : 'اختر القسم ثم التصنيف الفرعي';

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>📂</span>
        <div>
          <div className={styles.stepTitle}>اختر تصنيف الإعلان</div>
          <div className={styles.stepSub}>{headerSub}</div>
        </div>
      </header>

      {loading ? (
        <div className={styles.loadingWrap}>
          <div className={styles.spinner} />
        </div>
      ) : (
        <>
          {/* Search bar — shown at all levels */}
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
                  ? `ابحث في ${(subParent ?? w.parentCategory)?.name_ar ?? ''}...`
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

          {/* Subcategory / sub-subcategory level */}
          {w.parentCategory ? (
            <>
              <button
                type="button"
                className={`${pm.pmBtn} ${pm.pmBtnGhost} ${styles.catBackBtn}`}
                onClick={goBackLevel}
              >
                <Chevron back />{' '}
                {subParent ? `رجوع إلى ${w.parentCategory.name_ar}` : 'رجوع للأقسام'}
              </button>

              {filteredChildren.length === 0 ? (
                <div className={styles.catSearchEmpty}>
                  <div className={styles.catSearchEmptyIcon}>🔍</div>
                  لا توجد نتائج لـ «{search}»
                </div>
              ) : (
                <ul className={styles.catList} role="list">
                  {filteredChildren.map((c) => {
                    const drillable = !subParent && hasChildren(c);
                    return (
                      <li key={c.id}>
                        <button
                          type="button"
                          className={`${styles.catRow} ${w.category?.id === c.id ? styles.catRowActive : ''}`}
                          onClick={() => pickChild(c)}
                        >
                          <span className={styles.catRowName}>{highlightMatch(c.name_ar, q)}</span>
                          {drillable ? (
                            <span className={styles.catRowMeta}>{c.children?.length} تصنيف</span>
                          ) : (
                            <DealerFeeBadge fee={feeFor(c)} />
                          )}
                          <Chevron />
                        </button>
                      </li>
                    );
                  })}
                </ul>
              )}
            </>
          ) : isSearching && globalResults ? (
            /* Global search results across all category levels */
            globalResults.length === 0 ? (
              <div className={styles.catSearchEmpty}>
                <div className={styles.catSearchEmptyIcon}>🔍</div>
                لا توجد نتائج لـ «{search}»
              </div>
            ) : (
              <ul className={styles.catList} role="list">
                {globalResults.map(({ node, path }) => (
                  <li key={`${path.map((p) => p.id).join('-')}-${node.id}`}>
                    <button
                      type="button"
                      className={`${styles.catRow} ${w.category?.id === node.id ? styles.catRowActive : ''}`}
                      onClick={() => selectFromSearch(node, path)}
                    >
                      <span className={styles.catRowName}>{highlightMatch(node.name_ar, q)}</span>
                      {path.length > 0 && (
                        <span className={styles.catRowBreadcrumb}>
                          {path.map((p) => p.name_ar).join(' › ')}
                        </span>
                      )}
                      {hasChildren(node) ? (
                        <span className={styles.catRowMeta}>{node.children?.length} تصنيف</span>
                      ) : (
                        <DealerFeeBadge fee={feeFor(node)} />
                      )}
                      <Chevron />
                    </button>
                  </li>
                ))}
              </ul>
            )
          ) : (
            /* Normal parent category list */
            <ul className={styles.catList} role="list">
              {filteredParents.map((c) => {
                const childCount = c.children?.length ?? 0;
                return (
                  <li key={c.id}>
                    <button type="button" className={styles.catRow} onClick={() => pickParent(c)}>
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
