'use client';

import { useParams, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import styles from './pay.module.css';
import { fetchAd, type Ad } from '@/lib/api/ads';
import { useRequireAuth } from '@/hooks/useRequireAuth';
import { BankTransferPayment } from '../../_components/pay/BankTransferPayment';
import { usePostAdWizard } from '@/store/postAdWizard.store';

/**
 * Pay landing page for the after-sale commission. Loads the ad to surface the
 * owed commission. While payment gateways are not yet live, the seller pays by
 * bank transfer and uploads a receipt, which an admin reviews. White theme —
 * mirrors the mobile bank-transfer flow.
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

  const goToAd = () => {
    reset();
    if (ad) router.push(`/ar/ads/${ad.id}`);
  };

  return (
    <>
      <Header />
      <main className={styles.main}>
        <div className={styles.shell}>
          <h1 className={styles.pageTitle}>دفع عمولة البيع</h1>

          {error && <div className={styles.error}>{error}</div>}

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
                <div className={`${styles.statusPanel} ${styles.statusPaid}`}>
                  <div className={styles.statusTitle}>✅ تم استلام العمولة وتأكيدها</div>
                  <p className={styles.statusText}>شكراً لك. تم اعتماد دفع عمولة البيع بنجاح.</p>
                  <button className={styles.btnPrimary} onClick={goToAd}>
                    عرض الإعلان
                  </button>
                </div>
              ) : ad.payment_status === 'under_review' ? (
                <div className={`${styles.statusPanel} ${styles.statusReview}`}>
                  <div className={styles.statusTitle}>⏳ إيصال التحويل قيد المراجعة</div>
                  <p className={styles.statusText}>
                    استلمنا إيصال تحويل العمولة. سيقوم الفريق بمراجعته والتحقق منه، وسيتم اعتماد
                    الدفع فور التأكد من التحويل.
                  </p>
                  <button className={styles.btnGhost} onClick={goToAd}>
                    عرض الإعلان
                  </button>
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
