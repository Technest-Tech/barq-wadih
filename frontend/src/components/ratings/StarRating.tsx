'use client';

import React from 'react';
import styles from './StarRating.module.css';

interface StarRatingProps {
  value: number;          // Current value (avg or selected)
  count?: number;         // Rating count (for display mode)
  size?: 'sm' | 'md' | 'lg';
  interactive?: boolean;  // If true, clicking selects a star
  onChange?: (stars: number) => void;
}

export default function StarRating({
  value,
  count,
  size = 'md',
  interactive = false,
  onChange,
}: StarRatingProps) {
  const [hovered, setHovered] = React.useState(0);

  const safeValue = Number(value) || 0;
  const display = interactive ? (hovered || safeValue) : safeValue;

  return (
    <div className={`${styles.wrapper} ${styles[size]}`}>
      <div className={styles.stars}>
        {[1, 2, 3, 4, 5].map((star) => {
          const filled = display >= star;
          const half   = !filled && display >= star - 0.5;

          return (
            <span
              key={star}
              className={`${styles.star} ${filled ? styles.filled : half ? styles.half : styles.empty}`}
              onMouseEnter={() => interactive && setHovered(star)}
              onMouseLeave={() => interactive && setHovered(0)}
              onClick={() => interactive && onChange?.(star)}
              role={interactive ? 'button' : undefined}
              aria-label={interactive ? `${star} نجوم` : undefined}
            >
              ★
            </span>
          );
        })}
      </div>
      {count !== undefined && (
        <span className={styles.count}>
          {safeValue.toFixed(1)} · {count.toLocaleString('ar-SA')} تقييم
        </span>
      )}
    </div>
  );
}
