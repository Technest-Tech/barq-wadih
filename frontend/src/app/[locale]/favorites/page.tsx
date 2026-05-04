'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { fetchFavorites } from '@/lib/api/favorites';
import { useFavorite } from '@/lib/hooks/useFavorite';
import type { AdListItem } from '@/lib/api/ads';
import styles from './page.module.css';

// ── Favorite Ad Card ──────────────────────────────────────────────────────────

function FavoriteCard({ ad, onUnfavorite }: { ad: AdListItem; onUnfavorite: () => void }) {
  const { isFavorited, toggle, isLoading } = useFavorite(ad.id, {
    initialState: true,
    onToggle: (state) => { if (!state) onUnfavorite(); },
  });

  const price = ad.is_free ? null : ad.price
    ? `${parseFloat(String(ad.price)).toLocaleString('ar-SA')} ر.س`
    : null;

  return (
    <div className={styles.card}>
      <div className={styles.imageWrap}>
        {ad.primary_image?.thumbnail_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={ad.primary_image.thumbnail_url}
            alt={ad.title}
            className={styles.image}
          />
        ) : (
          <div className={styles.noImage}>📦</div>
        )}

        {ad.is_boosted && (
          <span className={styles.boostedBadge}>مميّز</span>
        )}

        <button
          className={`${styles.heartBtn} ${isFavorited ? styles.active : ''}`}
          onClick={toggle}
          disabled={isLoading}
          aria-label={isFavorited ? 'إزالة من المفضلة' : 'إضافة للمفضلة'}
        >
          {isFavorited ? '♥' : '♡'}
        </button>
      </div>

      <Link href={`/ar/ads/${ad.id}`} className={styles.cardBody}>
        <h3 className={styles.title}>{ad.title}</h3>

        {ad.is_free ? (
          <p className={styles.priceFree}>مجاني</p>
        ) : price ? (
          <p className={styles.price}>{price}</p>
        ) : null}

        <div className={styles.cardMeta}>
          {ad.city && (
            <span className={styles.location}>
              📍 {ad.city.name_ar}
            </span>
          )}
          {ad.category && (
            <span className={styles.category}>{ad.category.name_ar}</span>
          )}
        </div>
      </Link>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function FavoritesPage() {
  const [ads, setAds]         = useState<AdListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage]       = useState(1);
  const [hasMore, setHasMore] = useState(false);

  useEffect(() => {
    setLoading(true);
    fetchFavorites(1)
      .then((res) => {
        setAds(res.data);
        setHasMore(res.meta.current_page < res.meta.last_page);
      })
      .finally(() => setLoading(false));
  }, []);

  async function loadMore() {
    const next = page + 1;
    const res  = await fetchFavorites(next);
    setAds((prev) => [...prev, ...res.data]);
    setPage(next);
    setHasMore(res.meta.current_page < res.meta.last_page);
  }

  return (
    <>
      <Header />

      {/* ── Hero ── */}
      <section className={styles.hero}>
        <div className={styles.heroInner}>
          <div className={styles.heroTop}>
            <div className={styles.heroIcon}>♥</div>
            <div>
              <h1 className={styles.heroTitle}>المفضلة</h1>
              <p className={styles.heroSubtitle}>إعلاناتك المحفوظة في مكان واحد</p>
            </div>
          </div>
          {!loading && ads.length > 0 && (
            <div className={styles.heroBadge}>
              ♛ {ads.length} إعلان محفوظ
            </div>
          )}
        </div>
      </section>

      {/* ── Content ── */}
      <main className={styles.page}>
        <div className={styles.container}>

          {/* Toolbar */}
          {!loading && ads.length > 0 && (
            <div className={styles.toolbar}>
              <div className={styles.toolbarLeft}>
                <span className={styles.count}>
                  ♥ {ads.length} إعلان
                </span>
              </div>
              <Link href="/ar" className={styles.browseLink}>
                تصفّح المزيد من الإعلانات ›
              </Link>
            </div>
          )}

          {/* Grid */}
          {loading ? (
            <div className={styles.grid}>
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className={styles.skeleton} />
              ))}
            </div>
          ) : ads.length === 0 ? (
            <div className={styles.empty}>
              <div className={styles.emptyIllustration}>🤍</div>
              <h2>لا توجد إعلانات مفضلة</h2>
              <p>احفظ الإعلانات التي تعجبك لتجدها هنا في أي وقت</p>
              <Link href="/ar" className={styles.browseBtn}>
                تصفّح الإعلانات
              </Link>
            </div>
          ) : (
            <>
              <div className={styles.grid}>
                {ads.map((ad) => (
                  <FavoriteCard
                    key={ad.id}
                    ad={ad}
                    onUnfavorite={() => setAds((prev) => prev.filter((a) => a.id !== ad.id))}
                  />
                ))}
              </div>

              {hasMore && (
                <div className={styles.loadMoreWrap}>
                  <button className={styles.loadMore} onClick={loadMore}>
                    تحميل المزيد
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </main>

      <Footer />
    </>
  );
}
