'use client';

import styles from '../../post-ad.module.css';

type Props = {
  /** Picked from category.publish_fee_individual or _dealer based on user.is_dealer. */
  fee: number | null;
};

/**
 * Tiny badge rendered on the leaf-category cards and review fee breakdown.
 * Hides when fee is null or 0 — those categories are free to publish.
 */
export function DealerFeeBadge({ fee }: Props) {
  if (fee === null || fee <= 0) {
    return <span className={`${styles.feeBadge} ${styles.feeBadgeFree}`}>مجاني</span>;
  }
  return (
    <span className={styles.feeBadge}>
      <span>💰</span>
      {fee.toLocaleString('ar-SA')} ر.س
    </span>
  );
}
