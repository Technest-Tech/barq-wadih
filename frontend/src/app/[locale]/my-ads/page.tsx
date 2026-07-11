'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import { fetchMyAds, deleteAd, markAdSold, type AdListItem } from '@/lib/api/ads';
import { boostAd, refreshAd } from '@/lib/api/boosts';
import { useRequireAuth } from '@/hooks/useRequireAuth';
import styles from './page.module.css';

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUS_CONFIG: Record<string, { label: string; cls: string }> = {
  active: { label: 'نشط', cls: 'active' },
  sold: { label: 'مُباع', cls: 'sold' },
  expired: { label: 'منتهي', cls: 'expired' },
  pending_review: { label: 'قيد المراجعة', cls: 'pending' },
  rejected: { label: 'مرفوض', cls: 'rejected' },
  deleted: { label: 'محذوف', cls: 'deleted' },
};

const STATUS_TABS = [
  { key: 'all', label: 'الكل' },
  { key: 'active', label: 'نشط' },
  { key: 'sold', label: 'مُباع' },
  { key: 'expired', label: 'منتهي' },
  { key: 'pending_review', label: 'قيد المراجعة' },
];

function daysUntil(dateStr: string | null): number | null {
  if (!dateStr) return null;
  const diff = new Date(dateStr).getTime() - Date.now();
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

function hoursUntil(dateStr: string | null): number | null {
  if (!dateStr) return null;
  const diff = new Date(dateStr).getTime() - Date.now();
  const hours = Math.ceil(diff / (1000 * 60 * 60));
  return hours > 0 ? hours : null;
}

function formatCountdown(dateStr: string | null): string {
  const h = hoursUntil(dateStr);
  if (!h) return '';
  if (h > 24) return `${Math.ceil(h / 24)} يوم`;
  return `${h} ساعة`;
}

// ── Component ─────────────────────────────────────────────────────────────────

type SoldSheet = { id: number; title: string; commission: number };

export default function MyAdsPage() {
  const { ready } = useRequireAuth();
  const router = useRouter();
  const [ads, setAds] = useState<AdListItem[]>([]);
  const [soldSheet, setSoldSheet] = useState<SoldSheet | null>(null);
  const [loading, setLoading] = useState(true);
  const [actionId, setActionId] = useState<number | null>(null);
  const [activeTab, setActiveTab] = useState('all');
  const [page, setPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [loadingMore, setLoadingMore] = useState(false);

  // ── Load ads ──────────────────────────────────────────────────────────────

  useEffect(() => {
    if (!ready) return;
    setLoading(true);
    setPage(1);
    fetchMyAds()
      .then((r) => {
        setAds(r.data);
        setLastPage(r.meta?.last_page ?? 1);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [ready]);

  const loadMore = async () => {
    if (page >= lastPage) return;
    setLoadingMore(true);
    try {
      const r = await fetchMyAds();
      setAds((prev) => [...prev, ...r.data]);
      setPage((p) => p + 1);
    } catch {
      /* ignore */
    } finally {
      setLoadingMore(false);
    }
  };

  // ── Actions ───────────────────────────────────────────────────────────────

  const handleDelete = async (id: number) => {
    if (!confirm('هل أنت متأكد من حذف هذا الإعلان؟')) return;
    setActionId(id);
    await deleteAd(id).catch(console.error);
    setAds((prev) => prev.filter((a) => a.id !== id));
    setActionId(null);
  };

  const handleSold = async (id: number) => {
    setActionId(id);
    const updated = await markAdSold(id).catch(() => null);
    if (updated) {
      setAds((prev) =>
        prev.map((a) =>
          a.id === id
            ? {
                ...a,
                status: 'sold',
                status_label: 'مُباع',
                payment_status: updated.payment_status ?? a.payment_status,
                payment_amount: updated.payment_amount ?? a.payment_amount,
              }
            : a
        )
      );
      // Mirror the mobile SoldFeeSheet: congratulate and surface the owed
      // commission with a "pay now" CTA (free categories owe nothing).
      const sold = ads.find((a) => a.id === id);
      setSoldSheet({
        id,
        title: sold?.title ?? '',
        commission: Number(updated.payment_amount ?? 0),
      });
    }
    setActionId(null);
  };

  // ── Boost / Refresh ──────────────────────────────────────────────────────
  const [boostTarget, setBoostTarget] = useState<number | null>(null);
  const [boostLoading, setBoostLoading] = useState(false);

  const handleBoost = async () => {
    if (!boostTarget) return;
    setBoostLoading(true);
    try {
      await boostAd(boostTarget);
      setAds((prev) =>
        prev.map((a) =>
          a.id === boostTarget
            ? {
                ...a,
                is_boosted: true,
                boosted_until: new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString(),
              }
            : a
        )
      );
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'حدث خطأ';
      alert(msg);
    } finally {
      setBoostLoading(false);
      setBoostTarget(null);
    }
  };

  const handleRefresh = async (id: number) => {
    setActionId(id);
    try {
      await refreshAd(id);
      setAds((prev) =>
        prev.map((a) => (a.id === id ? { ...a, published_at: new Date().toISOString() } : a))
      );
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'حدث خطأ';
      alert(msg);
    } finally {
      setActionId(null);
    }
  };

  // ── Filter ────────────────────────────────────────────────────────────────

  const filtered = activeTab === 'all' ? ads : ads.filter((a) => a.status === activeTab);

  // ── Counts ────────────────────────────────────────────────────────────────

  const counts: Record<string, number> = { all: ads.length };
  STATUS_TABS.slice(1).forEach((t) => {
    counts[t.key] = ads.filter((a) => a.status === t.key).length;
  });

  if (!ready) return null;

  return (
    <>
      <Header />
      <main className={styles.main}>
        <div className={styles.container}>
          <div className={styles.topRow}>
            <h1 className={styles.pageTitle}>إعلاناتي</h1>
            <Link href="/ar/post-ad" className={styles.btnNew}>
              + إعلان جديد
            </Link>
          </div>

          {/* ── Status tabs ── */}
          <div className={styles.tabBar}>
            {STATUS_TABS.map((tab) => (
              <button
                key={tab.key}
                className={`${styles.tab} ${activeTab === tab.key ? styles.tabActive : ''}`}
                onClick={() => setActiveTab(tab.key)}
              >
                {tab.label}
                {counts[tab.key] > 0 && <span className={styles.tabCount}>{counts[tab.key]}</span>}
              </button>
            ))}
          </div>

          {/* ── Loading skeletons ── */}
          {loading && (
            <div className={styles.skeletonList}>
              {[1, 2, 3].map((i) => (
                <div key={i} className={styles.skeletonCard} />
              ))}
            </div>
          )}

          {/* ── Empty state ── */}
          {!loading && filtered.length === 0 && (
            <div className={styles.empty}>
              <span className={styles.emptyIcon}>📋</span>
              <h3>
                {activeTab === 'all'
                  ? 'لا توجد إعلانات بعد'
                  : `لا توجد إعلانات بحالة "${STATUS_TABS.find((t) => t.key === activeTab)?.label}"`}
              </h3>
              {activeTab === 'all' && <p>انشر إعلانك الأول الآن وابدأ في البيع!</p>}
              {activeTab === 'all' && (
                <Link href="/ar/post-ad" className={styles.btnNew}>
                  نشر إعلان
                </Link>
              )}
            </div>
          )}

          {/* ── Ad list ── */}
          {!loading && filtered.length > 0 && (
            <div className={styles.adList}>
              {filtered.map((ad) => {
                const sc = STATUS_CONFIG[ad.status] ?? { label: ad.status, cls: 'pending' };
                const busy = actionId === ad.id;
                const daysLeft = daysUntil(
                  ad.published_at
                    ? ((ad as AdListItem & { expires_at?: string }).expires_at ?? null)
                    : null
                );
                const isExpiringSoon =
                  daysLeft !== null && daysLeft <= 5 && daysLeft > 0 && ad.status === 'active';

                return (
                  <div key={ad.id} className={`${styles.adCard} ${busy ? styles.adCardBusy : ''}`}>
                    <div className={styles.adImageWrap}>
                      {ad.primary_image ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={ad.primary_image.thumbnail_url}
                          alt={ad.title}
                          className={styles.adImage}
                        />
                      ) : (
                        <div className={styles.adImagePlaceholder}>{ad.category?.icon ?? '📦'}</div>
                      )}
                      {ad.is_boosted && <span className={styles.boostedBadge}>⚡ مميز</span>}
                    </div>
                    <div className={styles.adBody}>
                      <div className={styles.adMeta}>
                        <span className={`${styles.statusBadge} ${styles[sc.cls]}`}>
                          {sc.label}
                        </span>
                        <span className={styles.adDate}>
                          {new Date(ad.created_at).toLocaleDateString('ar-SA')}
                        </span>
                      </div>
                      <Link href={`/ar/ads/${ad.id}`} className={styles.adTitle}>
                        {ad.title}
                      </Link>
                      <p className={styles.adPrice}>
                        {ad.is_free
                          ? 'مجاني'
                          : `${Number(ad.price ?? 0).toLocaleString('ar-SA')} ر.س`}
                        {ad.is_negotiable && <span className={styles.neg}>على السوم</span>}
                      </p>
                      <p className={styles.adLocation}>
                        {ad.city?.name_ar} • {ad.category?.name_ar}
                      </p>
                      {isExpiringSoon && (
                        <p className={styles.expiryWarning}>
                          ⏰ ينتهي خلال {daysLeft} {daysLeft === 1 ? 'يوم' : 'أيام'}
                        </p>
                      )}
                    </div>
                    <div className={styles.adActions}>
                      {ad.status === 'active' && (
                        <>
                          {/* Boost button — only if not currently boosted */}
                          {!ad.is_boosted || !hoursUntil(ad.boosted_until) ? (
                            <button
                              className={`${styles.actionBtn} ${styles.boostBtn}`}
                              disabled={busy}
                              onClick={() => setBoostTarget(ad.id)}
                            >
                              🚀 ترقية
                            </button>
                          ) : (
                            <div>
                              <span
                                className={styles.boostedBadge}
                                style={{ position: 'static', fontSize: '.72rem' }}
                              >
                                ⚡ مميز
                              </span>
                              <p className={styles.boostCountdown}>
                                باقي {formatCountdown(ad.boosted_until)}
                              </p>
                            </div>
                          )}

                          {/* Refresh button */}
                          <button
                            className={`${styles.actionBtn} ${styles.refreshBtn}`}
                            disabled={busy}
                            onClick={() => handleRefresh(ad.id)}
                          >
                            🔄 تحديث
                          </button>

                          <button
                            className={`${styles.actionBtn} ${styles.soldBtn}`}
                            disabled={busy}
                            onClick={() => handleSold(ad.id)}
                          >
                            {busy ? '...' : '✓ مُباع'}
                          </button>
                        </>
                      )}
                      {ad.status === 'sold' &&
                        (ad.payment_status === 'pending' || ad.payment_status === 'failed') &&
                        Number(ad.payment_amount ?? 0) > 0 && (
                          <Link
                            href={`/ar/post-ad/pay/${ad.id}`}
                            className={`${styles.actionBtn} ${styles.soldBtn}`}
                          >
                            💳 دفع العمولة ({Number(ad.payment_amount ?? 0).toLocaleString('ar-SA')}{' '}
                            ر.س)
                          </Link>
                        )}
                      {ad.status === 'sold' && ad.payment_status === 'under_review' && (
                        <span className={`${styles.statusBadge} ${styles.sold}`}>
                          العمولة قيد المراجعة
                        </span>
                      )}
                      {(ad.status === 'active' || ad.status === 'pending_review') && (
                        <Link
                          href={`/ar/post-ad?edit=${ad.id}`}
                          className={`${styles.actionBtn} ${styles.editBtn}`}
                        >
                          تعديل
                        </Link>
                      )}
                      {ad.status !== 'deleted' && (
                        <button
                          className={`${styles.actionBtn} ${styles.deleteBtn}`}
                          disabled={busy}
                          onClick={() => handleDelete(ad.id)}
                        >
                          {busy ? '...' : 'حذف'}
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* ── Load more ── */}
          {!loading && page < lastPage && (
            <div className={styles.loadMoreWrap}>
              <button className={styles.loadMoreBtn} onClick={loadMore} disabled={loadingMore}>
                {loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'}
              </button>
            </div>
          )}
        </div>

        {/* ── Sold success sheet (mirrors mobile SoldFeeSheet) ── */}
        {soldSheet && (
          <div className={styles.modalOverlay} onClick={() => setSoldSheet(null)}>
            <div className={styles.modalCard} onClick={(e) => e.stopPropagation()}>
              <div className={styles.soldIcon}>✅</div>
              <h3>بارك الله لك في بيعك وشرائك</h3>
              {soldSheet.title && <p className={styles.soldAdTitle}>{soldSheet.title}</p>}

              {soldSheet.commission > 0 ? (
                <>
                  <div className={styles.commissionCard}>
                    <span className={styles.commissionLabel}>عمولة المنصة المستحقة</span>
                    <span className={styles.commissionAmount}>
                      {soldSheet.commission.toLocaleString('ar-SA')} ر.س
                    </span>
                  </div>
                  <p className={styles.commissionNote}>
                    وأبرئ ذمتك بدفع عمولة الموقع.
                    <br />
                    عمولة ثابتة شاملة ضريبة القيمة المضافة، تُدفع عبر تحويل بنكي ثم تُراجَع من
                    الإدارة.
                  </p>
                  <div className={styles.modalActions}>
                    <button
                      className={styles.modalConfirm}
                      onClick={() => {
                        const id = soldSheet.id;
                        setSoldSheet(null);
                        router.push(`/ar/post-ad/pay/${id}`);
                      }}
                    >
                      💳 دفع العمولة الآن
                    </button>
                    <button className={styles.modalCancel} onClick={() => setSoldSheet(null)}>
                      لاحقاً
                    </button>
                  </div>
                </>
              ) : (
                <>
                  <p className={styles.commissionNote}>
                    هذا القسم مجاني بالكامل — لا توجد عمولة مستحقة.
                  </p>
                  <div className={styles.modalActions}>
                    <button className={styles.modalConfirm} onClick={() => setSoldSheet(null)}>
                      تم
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        )}

        {/* ── Boost confirmation modal ── */}
        {boostTarget && (
          <div className={styles.modalOverlay} onClick={() => setBoostTarget(null)}>
            <div className={styles.modalCard} onClick={(e) => e.stopPropagation()}>
              <div className={styles.modalIcon}>🚀</div>
              <h3>ترقية الإعلان</h3>
              <p>
                سيظهر إعلانك في أعلى نتائج البحث لمدة <strong>72 ساعة</strong> مع شارة ⚡ مميز.
                <br />
                مجاني خلال الفترة التجريبية!
              </p>
              <div className={styles.modalActions}>
                <button
                  className={styles.modalConfirm}
                  onClick={handleBoost}
                  disabled={boostLoading}
                >
                  {boostLoading ? 'جارٍ الترقية...' : '⚡ ترقية الآن'}
                </button>
                <button className={styles.modalCancel} onClick={() => setBoostTarget(null)}>
                  إلغاء
                </button>
              </div>
            </div>
          </div>
        )}
      </main>
      <Footer />
    </>
  );
}
