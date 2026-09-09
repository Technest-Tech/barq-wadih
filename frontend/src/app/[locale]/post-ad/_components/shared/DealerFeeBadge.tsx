'use client';

import styles from '../../post-ad.module.css';

type Props = {
  /** Flat after-sale commission resolved for the signed-in account tier. */
  fee: number | null;
};

/**
 * Tiny badge on leaf-category cards. Publishing is free, so this shows the flat
 * commission owed AFTER a sale. Free categories (e.g. Jobs) show "مجاني".
 */
export function DealerFeeBadge({ fee }: Props) {
  if (fee === null || fee <= 0) {
    return <span className={`${styles.feeBadge} ${styles.feeBadgeFree}`}>مجاني</span>;
  }
  return (
    <span className={styles.feeBadge}>
      <span>💰</span>
      عمولة {fee.toLocaleString('ar-SA')} ر.س بعد البيع
    </span>
  );
}
