'use client';

import styles from './error.module.css';

type Props = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function ErrorPage({ error, reset }: Props) {
  return (
    <main className={styles.container}>
      <div className={styles.content}>
        <div className={styles.icon}>⚠️</div>
        <h2 className={styles.title}>خطأ في الخادم</h2>
        <p className={styles.description}>
          {process.env.NODE_ENV === 'development' ? error.message : 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.'}
        </p>
        <button onClick={reset} className={styles.retryButton}>
          إعادة المحاولة
        </button>
      </div>
    </main>
  );
}
