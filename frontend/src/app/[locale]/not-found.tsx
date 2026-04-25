import { useTranslations } from 'next-intl';
import Link from 'next/link';
import styles from './not-found.module.css';

export default function NotFound() {
  const t = useTranslations('errors');

  return (
    <main className={styles.container}>
      <div className={styles.content}>
        <h1 className={styles.code}>404</h1>
        <h2 className={styles.title}>{t('notFound')}</h2>
        <p className={styles.description}>{t('notFoundDescription')}</p>
        <Link href="/" className={styles.homeLink}>
          {t('goHome')}
        </Link>
      </div>
    </main>
  );
}
