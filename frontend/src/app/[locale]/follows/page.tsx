'use client';

import Link from 'next/link';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { useFollowedSellers } from '@/lib/sellerFollows';
import { toggleSellerFollow, type FollowedSellerEntry } from '@/lib/api/sellerFollows';
import styles from './page.module.css';

function formatRelative(iso: string | null): string {
  if (!iso) return '';
  const diffMs = Date.now() - new Date(iso).getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return 'الآن';
  if (diffMin < 60) return `منذ ${diffMin} دقيقة`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `منذ ${diffHr} ساعة`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 30) return `منذ ${diffDay} يوم`;
  return new Date(iso).toLocaleDateString('ar-SA');
}

function SellerCard({
  entry,
  onUnfollow,
}: {
  entry: FollowedSellerEntry;
  onUnfollow: (sellerId: number) => void;
}) {
  const { seller, created_at } = entry;
  return (
    <div className={styles.card}>
      <Link href={`/ar/users/${seller.id}`} className={styles.avatarWrap}>
        {seller.avatar ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={seller.avatar} alt={seller.name} />
        ) : (
          <span>{seller.name?.charAt(0) ?? '؟'}</span>
        )}
      </Link>
      <h3 className={styles.name}>
        <Link href={`/ar/users/${seller.id}`} style={{ color: 'inherit', textDecoration: 'none' }}>
          {seller.name}
        </Link>
      </h3>
      <p className={styles.followedAt}>تمت المتابعة {formatRelative(created_at)}</p>
      <button
        className={styles.unfollowBtn}
        onClick={() => onUnfollow(seller.id)}
      >
        إلغاء المتابعة
      </button>
    </div>
  );
}

export default function FollowsPage() {
  const { list, loading, error, reload } = useFollowedSellers();

  const handleUnfollow = async (sellerId: number) => {
    try {
      await toggleSellerFollow(sellerId);
      // Notify other components and refresh local list.
      if (typeof window !== 'undefined') {
        window.dispatchEvent(
          new CustomEvent('bw:seller_follows_changed', {
            detail: { sellerId, following: false },
          }),
        );
      }
      reload();
    } catch {
      // ignore — UI stays in sync via reload on next render
    }
  };

  return (
    <>
      <Header />

      <section className={styles.hero}>
        <div className={styles.heroInner}>
          <div className={styles.heroTop}>
            <div className={styles.heroIcon}>👥</div>
            <div>
              <h1 className={styles.heroTitle}>المتابَعون</h1>
              <p className={styles.heroSubtitle}>قائمة المعلنين الذين تتابعهم</p>
            </div>
          </div>
          {list.length > 0 && (
            <div className={styles.heroBadge}>
              ★ {list.length} {list.length === 1 ? 'معلن' : 'معلنين'}
            </div>
          )}
        </div>
      </section>

      <main className={styles.page}>
        <div className={styles.container}>
          {loading ? (
            <div className={styles.empty}>
              <p>جاري التحميل…</p>
            </div>
          ) : error ? (
            <div className={styles.empty}>
              <h2>تعذر تحميل القائمة</h2>
              <button className={styles.browseBtn} onClick={() => reload()}>
                إعادة المحاولة
              </button>
            </div>
          ) : list.length === 0 ? (
            <div className={styles.empty}>
              <div className={styles.emptyIllustration}>👥</div>
              <h2>لا تتابع أي معلن بعد</h2>
              <p>اضغط زر &laquo;متابعة&raquo; بجانب اسم المعلن لإضافته هنا.</p>
              <Link href="/ar" className={styles.browseBtn}>تصفّح الإعلانات</Link>
            </div>
          ) : (
            <div className={styles.grid}>
              {list.map((entry) => (
                <SellerCard
                  key={entry.id}
                  entry={entry}
                  onUnfollow={handleUnfollow}
                />
              ))}
            </div>
          )}
        </div>
      </main>

      <Footer />
    </>
  );
}
