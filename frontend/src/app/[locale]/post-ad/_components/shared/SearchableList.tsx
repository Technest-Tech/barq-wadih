'use client';

import { useMemo, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';

export type ListItem = {
  id: number | string;
  label: string;
  /** Optional secondary line shown to the end of the row. */
  meta?: string;
  icon?: string | null;
};

type Props<T extends ListItem> = {
  items: T[];
  selectedId?: T['id'] | null;
  placeholder?: string;
  emptyText?: string;
  onSelect: (item: T) => void;
};

/**
 * Searchable picker used by Region, City, and District steps. Filters
 * client-side on `label`. Item rows are buttons (not links) so they don't
 * trigger router navigation when clicked inside the wizard.
 */
export function SearchableList<T extends ListItem>({
  items,
  selectedId,
  placeholder = 'ابحث...',
  emptyText = 'لا توجد نتائج',
  onSelect,
}: Props<T>) {
  const [q, setQ] = useState('');

  const filtered = useMemo(() => {
    const needle = q.trim();
    if (!needle) return items;
    return items.filter(i => i.label.includes(needle) || (i.meta ?? '').includes(needle));
  }, [items, q]);

  return (
    <div>
      <input
        className={`${pm.pmInput} ${styles.searchInput}`}
        type="search"
        placeholder={placeholder}
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      {filtered.length === 0 ? (
        <div className={pm.pmEmpty}>
          <div className={pm.pmEmptyIcon}>🔍</div>
          <div className={pm.pmEmptyText}>{emptyText}</div>
        </div>
      ) : (
        <div className={styles.optionsList}>
          {filtered.map(item => (
            <button
              key={item.id}
              type="button"
              className={`${styles.option} ${item.id === selectedId ? styles.optionSelected : ''}`}
              onClick={() => onSelect(item)}
            >
              {item.icon && <span className={styles.optionIcon}>{item.icon}</span>}
              <span>{item.label}</span>
              {item.meta && <span className={styles.optionMeta}>{item.meta}</span>}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
