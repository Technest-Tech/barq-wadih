'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { fetchBanners, trackBannerClick, type IBanner } from '@/lib/api/banners';
import styles from './BannerCarousel.module.css';

// ── Props ─────────────────────────────────────────────────────────────────────

interface BannerCarouselProps {
  position: 'home_top' | 'home_middle' | 'category_top';
  /** Auto-slide interval in ms. Default: 5000 */
  interval?: number;
}

// ── Link type badge labels ────────────────────────────────────────────────────

const LINK_LABELS: Record<string, string> = {
  ad: '📋 عرض الإعلان',
  whatsapp: '💬 واتساب',
  url: '🔗 زيارة الرابط',
};

// ── Component ─────────────────────────────────────────────────────────────────

export default function BannerCarousel({
  position,
  interval = 5000,
}: BannerCarouselProps) {
  const [banners, setBanners] = useState<IBanner[]>([]);
  const [current, setCurrent] = useState(0);
  const [loading, setLoading] = useState(true);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // ── Fetch banners ──────────────────────────────────────────────────────────
  useEffect(() => {
    let cancelled = false;
    fetchBanners(position)
      .then((data) => {
        if (!cancelled) setBanners(data);
      })
      .catch(console.error)
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => { cancelled = true; };
  }, [position]);

  // ── Auto-slide timer ───────────────────────────────────────────────────────
  const resetTimer = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    if (banners.length <= 1) return;
    timerRef.current = setInterval(() => {
      setCurrent((prev) => (prev + 1) % banners.length);
    }, interval);
  }, [banners.length, interval]);

  useEffect(() => {
    resetTimer();
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [resetTimer]);

  // ── Navigation ─────────────────────────────────────────────────────────────
  const goTo = (idx: number) => {
    setCurrent(idx);
    resetTimer();
  };

  const goPrev = () => goTo((current - 1 + banners.length) % banners.length);
  const goNext = () => goTo((current + 1) % banners.length);

  // ── Click handler ──────────────────────────────────────────────────────────
  const handleClick = async (banner: IBanner) => {
    try {
      const { redirect_url } = await trackBannerClick(banner.id);
      if (redirect_url) {
        // Internal links (ads) vs external
        if (redirect_url.startsWith('/')) {
          window.location.href = `/ar${redirect_url}`;
        } else {
          window.open(redirect_url, '_blank', 'noopener');
        }
      }
    } catch {
      // Silently handle tracking errors
    }
  };

  // ── Loading state ──────────────────────────────────────────────────────────
  if (loading) {
    return <div className={styles.skeleton} />;
  }

  // ── No banners — render nothing ────────────────────────────────────────────
  if (banners.length === 0) {
    return null;
  }

  return (
    <div
      className={styles.carousel}
      id={`banner-carousel-${position}`}
      onMouseEnter={() => {
        if (timerRef.current) clearInterval(timerRef.current);
      }}
      onMouseLeave={resetTimer}
    >
      {/* Slides */}
      <div
        className={styles.track}
        style={{ transform: `translateX(${current * 100}%)` }}
      >
        {banners.map((banner) => (
          <div
            key={banner.id}
            className={styles.slide}
            onClick={() => handleClick(banner)}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => { if (e.key === 'Enter') handleClick(banner); }}
          >
            {/* Desktop image */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={banner.image_url}
              alt={banner.title}
              className={styles.imageDesktop}
              loading="lazy"
            />
            {/* Mobile image */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={banner.image_url_mobile ?? banner.image_url}
              alt={banner.title}
              className={styles.imageMobile}
              loading="lazy"
            />

            {/* Title overlay */}
            <div className={styles.titleOverlay}>
              <span className={styles.titleText}>{banner.title}</span>
            </div>

            {/* Link type badge */}
            {banner.link_type !== 'none' && LINK_LABELS[banner.link_type] && (
              <span className={styles.linkBadge}>
                {LINK_LABELS[banner.link_type]}
              </span>
            )}
          </div>
        ))}
      </div>

      {/* Navigation arrows */}
      {banners.length > 1 && (
        <>
          <button
            className={`${styles.navBtn} ${styles.navPrev}`}
            onClick={(e) => { e.stopPropagation(); goPrev(); }}
            aria-label="السابق"
          >
            ›
          </button>
          <button
            className={`${styles.navBtn} ${styles.navNext}`}
            onClick={(e) => { e.stopPropagation(); goNext(); }}
            aria-label="التالي"
          >
            ‹
          </button>
        </>
      )}

      {/* Dot indicators */}
      {banners.length > 1 && (
        <div className={styles.dots}>
          {banners.map((_, idx) => (
            <button
              key={idx}
              className={`${styles.dot} ${idx === current ? styles.dotActive : ''}`}
              onClick={(e) => { e.stopPropagation(); goTo(idx); }}
              aria-label={`الشريحة ${idx + 1}`}
            />
          ))}
        </div>
      )}
    </div>
  );
}
