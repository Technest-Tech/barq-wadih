import styles from './Skeleton.module.css';

export type SkeletonProps = {
  width?: string;
  height?: string;
  borderRadius?: string;
  className?: string;
};

export default function Skeleton({ width = '100%', height = '1rem', borderRadius, className = '' }: SkeletonProps) {
  return (
    <div
      className={[styles.skeleton, className].filter(Boolean).join(' ')}
      style={{ width, height, borderRadius: borderRadius ?? 'var(--radius-md)' }}
      aria-hidden="true"
    />
  );
}

export function SkeletonCard() {
  return (
    <div className={styles.card}>
      <Skeleton height="200px" borderRadius="var(--radius-lg) var(--radius-lg) 0 0" />
      <div className={styles.cardBody}>
        <Skeleton height="1.25rem" width="70%" />
        <Skeleton height="1rem" width="40%" />
        <Skeleton height="1.5rem" width="50%" />
      </div>
    </div>
  );
}
