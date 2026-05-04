'use client';

import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { useRequireAuth } from '@/hooks/useRequireAuth';
import { PostAdWizard } from './_components/PostAdWizard';
import styles from './post-ad.module.css';

/**
 * Post-Ad page — thin shell that mounts the modular wizard. The earlier
 * 589-line monolith was replaced by the 9-step PostAdWizard living in
 * `_components/`. Feature flag `NEXT_PUBLIC_NEW_POST_AD=0` is no longer
 * supported — the new wizard is the only path.
 */
export default function PostAdPage() {
  const { ready } = useRequireAuth();

  if (!ready) {
    return (
      <>
        <Header />
        <main className={styles.main}>
          <div className={styles.shell}>
            <div className={styles.loadingWrap}>
              <div className={styles.spinner} />
            </div>
          </div>
        </main>
        <Footer />
      </>
    );
  }

  return (
    <>
      <Header />
      <main className={styles.main}>
        <PostAdWizard />
      </main>
      <Footer />
    </>
  );
}
