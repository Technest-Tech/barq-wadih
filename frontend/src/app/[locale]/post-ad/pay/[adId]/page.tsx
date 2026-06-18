'use client';

import { useParams, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { fetchAd, type Ad } from '@/lib/api/ads';
import { useRequireAuth } from '@/hooks/useRequireAuth';
import { BankTransferPayment } from '../../_components/pay/BankTransferPayment';
import { usePostAdWizard } from '@/store/postAdWizard.store';

/**
 * Pay landing page — kicks off after the wizard creates a paid-tier ad.
 * Loads the ad to surface the publish fee. While payment gateways are not yet
 * live, the seller pays by bank transfer and uploads a receipt, which an admin
 * reviews before the ad is published.
 */
export default function PayPage() {
  const router = useRouter();
  const params = useParams<{ adId: string }>();
  const adId = Number(params.adId);
  const { ready } = useRequireAuth();
  const reset = usePostAdWizard((s) => s.reset);

  const [ad, setAd] = useState<Ad | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!ready || !Number.isFinite(adId)) return;
    fetchAd(adId)
      .then(setAd)
      .catch((e) => setError((e as Error).message));
  }, [ready, adId]);

  if (!ready) return null;

  return (
    <>
      <Header />
      <main className={styles.main}>
        <div className={styles.shell}>
          <h1 className={styles.pageTitle}>دفع عمولة البيع</h1>

          {error && <div style={{ color: '#fca5a5', marginBottom: 12 }}>{error}</div>}

          {ad ? (
            <div className={styles.card}>
              <div className={styles.reviewCard}>
                {ad.images?.[0] && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={ad.images[0].image_url} alt={ad.title} />
                )}
                <div className={styles.reviewBody}>
                  <h3>{ad.title}</h3>
                  <div className={styles.reviewMeta}>
                    {ad.category?.name_ar}
                    {ad.city?.name_ar && ` • ${ad.city.name_ar}`}
                  </div>
                  <div className={styles.reviewPrice}>
                    عمولة البيع المستحقة: {Number(ad.payment_amount ?? 0).toLocaleString('ar-SA')}{' '}
                    ر.س
                  </div>
                </div>
              </div>

              {ad.payment_status === 'paid' ? (
                <div
                  style={{
                    marginTop: 16,
                    padding: 14,
                    background: 'rgba(16,185,129,0.1)',
                    border: '1px solid rgba(16,185,129,0.3)',
                    borderRadius: 12,
                  }}
                >
                  ✅ تم استلام العمولة وتأكيدها. شكراً لك.
                  <div style={{ marginTop: 10 }}>
                    <button
                      className={`${pm.pmBtn} ${pm.pmBtnPrimary}`}
                      onClick={() => {
                        reset();
                        router.push(`/ar/ads/${ad.id}`);
                      }}
                    >
                      عرض الإعلان
                    </button>
                  </div>
                </div>
              ) : ad.payment_status === 'under_review' ? (
                <div
                  style={{
                    marginTop: 16,
                    padding: 16,
                    background: 'rgba(245,158,11,0.1)',
                    border: '1px solid rgba(245,158,11,0.3)',
                    borderRadius: 12,
                  }}
                >
                  <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 6 }}>
                    ⏳ إيصال التحويل قيد المراجعة
                  </div>
                  <p style={{ fontSize: 13.5, color: '#cbd5e1', lineHeight: 1.7 }}>
                    استلمنا إيصال تحويل العمولة. سيقوم الفريق بمراجعته والتحقق منه، وسيتم اعتماد
                    الدفع فور التأكد من التحويل.
                  </p>
                  <div style={{ marginTop: 12 }}>
                    <button
                      className={pm.pmBtn}
                      onClick={() => {
                        reset();
                        router.push(`/ar/ads/${ad.id}`);
                      }}
                    >
                      عرض الإعلان
                    </button>
                  </div>
                </div>
              ) : (
                <div style={{ marginTop: 14 }}>
                  <BankTransferPayment
                    adId={ad.id}
                    amount={Number(ad.payment_amount ?? 0)}
                    reviewNote={ad.payment_review_note}
                    underReview={false}
                    onSubmitted={(updated) => setAd(updated)}
                  />
                </div>
              )}
            </div>
          ) : (
            <div className={styles.loadingWrap}>
              <div className={styles.spinner} />
            </div>
          )}
        </div>
      </main>
      <Footer />
    </>
  );
}
