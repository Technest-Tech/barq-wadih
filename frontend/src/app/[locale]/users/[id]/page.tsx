'use client';

import React, { use, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { fetchSellerProfile, fetchSellerAds, type SellerProfile } from '@/lib/api/users';
import { fetchUserRatings, type Rating } from '@/lib/api/ratings';
import { useIsFollowingSeller } from '@/lib/sellerFollows';
import { authApi } from '@/lib/api/auth';
import { useAuthStore } from '@/store/auth.store';
import type { AdListItem } from '@/lib/api/ads';
import styles from './page.module.css';

// ── Helpers ──────────────────────────────────────────────────────────────────

function formatJoinedDate(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('ar-SA', { year: 'numeric', month: 'long' });
}

function formatLastActive(iso: string | null): string | null {
  if (!iso) return null;
  const diff = Date.now() - new Date(iso).getTime();
  const min = Math.floor(diff / 60000);
  if (min < 5) return 'متصل الآن';
  if (min < 60) return `نشط قبل ${min} د`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `نشط قبل ${hr} س`;
  const days = Math.floor(hr / 24);
  if (days < 30) return `نشط قبل ${days} يوم`;
  return `نشط قبل ${Math.floor(days / 30)} شهر`;
}

function formatRelative(iso: string | null): string {
  if (!iso) return '';
  const diff = Date.now() - new Date(iso).getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return 'الآن';
  if (min < 60) return `منذ ${min} د`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `منذ ${hr} س`;
  const days = Math.floor(hr / 24);
  if (days < 30) return `منذ ${days} يوم`;
  return new Date(iso).toLocaleDateString('ar-SA');
}

function avgNumber(v: number | string): number {
  return typeof v === 'string' ? parseFloat(v) || 0 : v;
}

// ── Small components ─────────────────────────────────────────────────────────

function Stars({ value, size = 14 }: { value: number; size?: number }) {
  return (
    <span className={styles.stars} style={{ fontSize: size }}>
      {Array.from({ length: 5 }).map((_, i) => (
        <span key={i} className={i < Math.round(value) ? styles.starFull : styles.starEmpty}>
          ★
        </span>
      ))}
    </span>
  );
}

function AdCard({ ad }: { ad: AdListItem }) {
  const price = ad.is_free
    ? null
    : ad.price
      ? `${parseFloat(String(ad.price)).toLocaleString('ar-SA')} ر.س`
      : null;
  return (
    <Link href={`/ar/ads/${ad.id}`} className={styles.adCard}>
      <div className={styles.adImageWrap}>
        {ad.primary_image?.thumbnail_url ? (
          /* eslint-disable-next-line @next/next/no-img-element */
          <img src={ad.primary_image.thumbnail_url} alt={ad.title} className={styles.adImage} />
        ) : (
          <div className={styles.adNoImage}>📦</div>
        )}
        {ad.is_boosted && <span className={styles.boostedBadge}>⚡ مميّز</span>}
      </div>
      <div className={styles.adBody}>
        <h3 className={styles.adTitle}>{ad.title}</h3>
        {ad.is_free ? (
          <p className={styles.priceFree}>مجاني</p>
        ) : price ? (
          <p className={styles.price}>{price}</p>
        ) : null}
        <div className={styles.adMeta}>
          {ad.city && <span className={styles.location}>📍 {ad.city.name_ar}</span>}
          <span className={styles.adTime}>{formatRelative(ad.published_at ?? ad.created_at)}</span>
        </div>
      </div>
    </Link>
  );
}

function ReviewCard({ r }: { r: Rating }) {
  return (
    <div className={styles.reviewCard}>
      <div className={styles.reviewHeader}>
        <div className={styles.reviewerAvatarWrap}>
          {r.rater.avatar ? (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img src={r.rater.avatar} alt={r.rater.name} />
          ) : (
            <span>{r.rater.name?.charAt(0) ?? '؟'}</span>
          )}
        </div>
        <div className={styles.reviewerMeta}>
          <span className={styles.reviewerName}>{r.rater.name}</span>
          <Stars value={r.stars} size={13} />
        </div>
        <span className={styles.reviewTime}>{formatRelative(r.created_at)}</span>
      </div>
      {r.comment && <p className={styles.reviewBody}>{r.comment}</p>}
      {r.ad && (
        <Link href={`/ar/ads/${r.ad.id}`} className={styles.reviewAdRef}>
          # {r.ad.title}
        </Link>
      )}
    </div>
  );
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function SellerProfilePage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { id } = use(params);
  const userId = parseInt(id, 10);

  const [profile, setProfile]   = useState<SellerProfile | null>(null);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);

  const [tab, setTab] = useState<'ads' | 'reviews'>('ads');

  const [ads, setAds]                 = useState<AdListItem[]>([]);
  const [adsLoading, setAdsLoading]   = useState(false);
  const [adsPage, setAdsPage]         = useState(1);
  const [adsHasMore, setAdsHasMore]   = useState(false);

  const [reviews, setReviews]         = useState<Rating[]>([]);
  const [reviewsLoading, setRevLoad]  = useState(false);

  const { following, busy: followBusy, toggle: toggleFollow } = useIsFollowingSeller(userId);

  const currentUser = useAuthStore((s) => s.user);
  const updateAuthUser = useAuthStore((s) => s.updateUser);
  const isOwnProfile = currentUser?.id === userId;
  const avatarInputRef = useRef<HTMLInputElement | null>(null);
  const coverInputRef  = useRef<HTMLInputElement | null>(null);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingCover,  setUploadingCover]  = useState(false);

  const [editingBio, setEditingBio] = useState(false);
  const [bioText,    setBioText]    = useState('');
  const [savingBio,  setSavingBio]  = useState(false);

  async function handleAvatarChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setUploadingAvatar(true);
    try {
      const res = await authApi.uploadAvatar(file);
      const newUrl = res.data?.avatar_url ?? null;
      setProfile((p) => (p ? { ...p, avatar: newUrl } : p));
      if (currentUser) updateAuthUser({ ...currentUser, avatar_url: newUrl });
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل رفع الصورة');
    } finally {
      setUploadingAvatar(false);
    }
  }

  function openBioEdit() {
    setBioText(profile?.bio ?? '');
    setEditingBio(true);
  }

  async function saveBio() {
    setSavingBio(true);
    try {
      const res = await authApi.updateProfile({ bio: bioText.trim() });
      const newBio = res.data?.bio ?? bioText.trim();
      setProfile((p) => (p ? { ...p, bio: newBio } : p));
      if (currentUser) updateAuthUser({ ...currentUser, bio: newBio });
      setEditingBio(false);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل حفظ النبذة');
    } finally {
      setSavingBio(false);
    }
  }

  async function handleCoverChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setUploadingCover(true);
    try {
      const res = await authApi.uploadCover(file);
      const newUrl = res.data?.cover_image_url ?? null;
      setProfile((p) => (p ? { ...p, cover_image: newUrl } : p));
      if (currentUser) updateAuthUser({ ...currentUser, cover_image_url: newUrl });
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل رفع صورة الغلاف');
    } finally {
      setUploadingCover(false);
    }
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetchSellerProfile(userId)
      .then((p) => { if (!cancelled) setProfile(p); })
      .catch((e: unknown) => {
        if (!cancelled) setError(e instanceof Error ? e.message : 'فشل تحميل الملف');
      })
      .finally(() => { if (!cancelled) setLoading(false); });

    setAdsLoading(true);
    fetchSellerAds(userId, 1)
      .then((res) => {
        if (cancelled) return;
        setAds(res.data);
        setAdsHasMore(res.meta.current_page < res.meta.last_page);
        setAdsPage(1);
      })
      .finally(() => { if (!cancelled) setAdsLoading(false); });

    setRevLoad(true);
    fetchUserRatings(userId, 1)
      .then((res) => { if (!cancelled) setReviews(res.data); })
      .finally(() => { if (!cancelled) setRevLoad(false); });

    return () => { cancelled = true; };
  }, [userId]);

  async function loadMoreAds() {
    const next = adsPage + 1;
    const res = await fetchSellerAds(userId, next);
    setAds((prev) => [...prev, ...res.data]);
    setAdsPage(next);
    setAdsHasMore(res.meta.current_page < res.meta.last_page);
  }

  if (loading) {
    return (
      <>
        <Header />
        <div className={styles.cover} />
        <main className={styles.page}>
          <div className={styles.container}>
            <div className={styles.skeletonCard} />
            <div className={styles.skeletonCard} />
          </div>
        </main>
        <Footer />
      </>
    );
  }

  if (error || !profile) {
    return (
      <>
        <Header />
        <main className={styles.page}>
          <div className={styles.container}>
            <div className={styles.empty}>
              <div className={styles.emptyIllustration}>👤</div>
              <h2>تعذر تحميل ملف البائع</h2>
              <p>{error ?? 'البائع غير موجود.'}</p>
              <Link href="/ar" className={styles.browseBtn}>الرئيسية</Link>
            </div>
          </div>
        </main>
        <Footer />
      </>
    );
  }

  const avg     = avgNumber(profile.avg_rating);
  const dist    = profile.rating_distribution;
  const distMax = Math.max(1, ...Object.values(dist));
  const lastActive = formatLastActive(profile.last_active_at);

  return (
    <>
      <Header />

      {/* ── Cover banner ── */}
      <section
        className={`${styles.cover} ${profile.cover_image ? styles.coverWithImage : ''}`}
        style={profile.cover_image ? { backgroundImage: `url(${profile.cover_image})` } : undefined}
      >
        {profile.cover_image && <div className={styles.coverOverlay} />}
        {isOwnProfile && (
          <>
            <button
              type="button"
              className={styles.coverEditBtn}
              onClick={() => coverInputRef.current?.click()}
              disabled={uploadingCover}
              aria-label="تغيير صورة الغلاف"
            >
              {uploadingCover ? '...جارٍ الرفع' : '📷 تغيير الغلاف'}
            </button>
            <input
              ref={coverInputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              hidden
              onChange={handleCoverChange}
            />
          </>
        )}
      </section>

      <main className={styles.page}>
        <div className={styles.container}>

          {/* ── Identity card ── */}
          <section className={styles.identityCard}>
            <div className={styles.avatarWrap}>
              {profile.avatar ? (
                /* eslint-disable-next-line @next/next/no-img-element */
                <img src={profile.avatar} alt={profile.name} />
              ) : (
                <span>{profile.name?.charAt(0) ?? '؟'}</span>
              )}
              {profile.is_verified && <span className={styles.verifiedDot} title="موثوق">✓</span>}
              {isOwnProfile && (
                <>
                  <button
                    type="button"
                    className={styles.avatarEditBtn}
                    onClick={() => avatarInputRef.current?.click()}
                    disabled={uploadingAvatar}
                    aria-label="تغيير الصورة الشخصية"
                  >
                    {uploadingAvatar ? '...' : '📷'}
                  </button>
                  <input
                    ref={avatarInputRef}
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    hidden
                    onChange={handleAvatarChange}
                  />
                </>
              )}
            </div>

            <div className={styles.identityBody}>
              <div className={styles.nameRow}>
                <h1 className={styles.name}>{profile.name}</h1>
                {profile.is_verified && <span className={styles.verifiedBadge}>✓ موثوق</span>}
                {profile.is_dealer && <span className={styles.dealerBadge}>⭐ معرض</span>}
              </div>

              <div className={styles.metaRow}>
                <span>عضو منذ {formatJoinedDate(profile.member_since)}</span>
                {lastActive && (
                  <>
                    <span className={styles.metaDot}>·</span>
                    <span className={styles.online}>● {lastActive}</span>
                  </>
                )}
              </div>

              {editingBio ? (
                <div className={styles.bioEditWrap}>
                  <textarea
                    className={styles.bioTextarea}
                    value={bioText}
                    onChange={(e) => setBioText(e.target.value)}
                    maxLength={500}
                    rows={3}
                    placeholder="اكتب نبذة تعريفية عنك..."
                    autoFocus
                  />
                  <div className={styles.bioEditActions}>
                    <button
                      className={styles.bioSaveBtn}
                      onClick={saveBio}
                      disabled={savingBio}
                    >
                      {savingBio ? '...حفظ' : 'حفظ'}
                    </button>
                    <button
                      className={styles.bioCancelBtn}
                      onClick={() => setEditingBio(false)}
                      disabled={savingBio}
                    >
                      إلغاء
                    </button>
                  </div>
                </div>
              ) : (
                <div className={styles.bioRow}>
                  {profile.bio ? (
                    <p className={styles.bio}>{profile.bio}</p>
                  ) : isOwnProfile ? (
                    <p className={styles.bioPlaceholder}>أضف نبذة تعريفية...</p>
                  ) : null}
                  {isOwnProfile && (
                    <button
                      className={styles.bioEditBtn}
                      onClick={openBioEdit}
                      aria-label="تعديل النبذة"
                    >
                      ✏️
                    </button>
                  )}
                </div>
              )}

              <div className={styles.actionRow}>
                <button
                  className={`${styles.followBtn} ${following ? styles.followBtnActive : ''}`}
                  onClick={() => toggleFollow().catch(() => {})}
                  disabled={followBusy}
                >
                  {following ? '✓ تتم متابعته' : '+ متابعة'}
                </button>
                <Link href="/ar/messages" className={styles.messageBtn}>
                  ✉️ مراسلة
                </Link>
                <button
                  className={styles.iconBtn}
                  onClick={() => {
                    if (typeof window === 'undefined') return;
                    const url = window.location.href;
                    const nav = window.navigator as Navigator & {
                      share?: (data: { title?: string; url?: string }) => Promise<void>;
                    };
                    if (typeof nav.share === 'function') {
                      nav.share({ title: profile.name, url }).catch(() => {});
                    } else if (nav.clipboard) {
                      nav.clipboard.writeText(url).catch(() => {});
                    }
                  }}
                  aria-label="مشاركة"
                >
                  ↗
                </button>
              </div>
            </div>
          </section>

          {/* ── Stats grid ── */}
          <section className={styles.statsGrid}>
            <div className={styles.statBox}>
              <div className={styles.statValue}>{profile.active_ads_count}</div>
              <div className={styles.statLabel}>إعلان نشط</div>
            </div>
            <div className={styles.statBox}>
              <div className={styles.statValue}>{profile.sold_ads_count}</div>
              <div className={styles.statLabel}>تم بيعه</div>
            </div>
            <div className={styles.statBox}>
              <div className={styles.statValue}>
                {avg.toFixed(1)} <span className={styles.statSuffix}>★</span>
              </div>
              <div className={styles.statLabel}>متوسط التقييم</div>
            </div>
            <div className={styles.statBox}>
              <div className={styles.statValue}>{profile.rating_count}</div>
              <div className={styles.statLabel}>تقييم</div>
            </div>
          </section>

          {/* ── Rating distribution ── */}
          {profile.rating_count > 0 && (
            <section className={styles.distributionCard}>
              <h3 className={styles.sectionTitle}>توزيع التقييمات</h3>
              <div className={styles.distributionBody}>
                <div className={styles.distMain}>
                  <div className={styles.distAvg}>{avg.toFixed(1)}</div>
                  <Stars value={avg} size={18} />
                  <div className={styles.distCount}>
                    بناءً على {profile.rating_count} تقييم
                  </div>
                </div>
                <div className={styles.distBars}>
                  {[5, 4, 3, 2, 1].map((star) => {
                    const count = dist[String(star)] ?? 0;
                    const pct = (count / distMax) * 100;
                    return (
                      <div key={star} className={styles.distRow}>
                        <span className={styles.distRowLabel}>
                          {star} <span className={styles.starInline}>★</span>
                        </span>
                        <span className={styles.distBarTrack}>
                          <span className={styles.distBarFill} style={{ width: `${pct}%` }} />
                        </span>
                        <span className={styles.distRowCount}>{count}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </section>
          )}

          {/* ── Tabs ── */}
          <div className={styles.tabs} role="tablist">
            <button
              role="tab"
              aria-selected={tab === 'ads'}
              className={`${styles.tab} ${tab === 'ads' ? styles.tabActive : ''}`}
              onClick={() => setTab('ads')}
            >
              الإعلانات <span className={styles.tabCount}>{profile.active_ads_count}</span>
            </button>
            <button
              role="tab"
              aria-selected={tab === 'reviews'}
              className={`${styles.tab} ${tab === 'reviews' ? styles.tabActive : ''}`}
              onClick={() => setTab('reviews')}
            >
              التقييمات <span className={styles.tabCount}>{profile.rating_count}</span>
            </button>
          </div>

          {/* ── Tab body ── */}
          {tab === 'ads' ? (
            adsLoading && ads.length === 0 ? (
              <div className={styles.adsGrid}>
                {Array.from({ length: 6 }).map((_, i) => (
                  <div key={i} className={styles.adSkeleton} />
                ))}
              </div>
            ) : ads.length === 0 ? (
              <div className={styles.tabEmpty}>
                <div className={styles.tabEmptyIcon}>📦</div>
                <p>لا توجد إعلانات نشطة لهذا البائع</p>
              </div>
            ) : (
              <>
                <div className={styles.adsGrid}>
                  {ads.map((ad) => <AdCard key={ad.id} ad={ad} />)}
                </div>
                {adsHasMore && (
                  <div className={styles.loadMoreWrap}>
                    <button className={styles.loadMore} onClick={loadMoreAds}>
                      تحميل المزيد
                    </button>
                  </div>
                )}
              </>
            )
          ) : (
            reviewsLoading ? (
              <div className={styles.reviewsList}>
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className={styles.reviewSkeleton} />
                ))}
              </div>
            ) : reviews.length === 0 ? (
              <div className={styles.tabEmpty}>
                <div className={styles.tabEmptyIcon}>⭐</div>
                <p>لا توجد تقييمات بعد</p>
              </div>
            ) : (
              <div className={styles.reviewsList}>
                {reviews.map((r) => <ReviewCard key={r.id} r={r} />)}
              </div>
            )
          )}
        </div>
      </main>

      <Footer />
    </>
  );
}
