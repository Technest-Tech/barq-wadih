'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { createAd, fetchCategoryFields, type CategoryField, type CategoryFieldOption } from '@/lib/api/ads';
import { useAuthStore } from '@/store/auth.store';
import { normalizePhone, usePostAdWizard } from '@/store/postAdWizard.store';
import { WizardFooter } from '../WizardFooter';

export function ReviewStep() {
  const router = useRouter();
  const user = useAuthStore(s => s.user);
  const w = usePostAdWizard();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeImg, setActiveImg] = useState(0);
  const [fields, setFields] = useState<CategoryField[]>([]);

  useEffect(() => {
    if (!w.category) return;
    fetchCategoryFields(w.category.id).then(setFields).catch(() => {});
  }, [w.category]);

  const visibleImages = w.images.filter(i => !i.removed);

  // Resolve the human-readable label for each filled-in dynamic field.
  const fieldRows = useMemo(() => {
    const rows: { key: string; label: string; value: string }[] = [];
    for (const f of fields) {
      const raw = w.details.fields[f.field_key];
      if (!raw) continue;
      let display = raw;
      if (Array.isArray(f.options)) {
        const match = f.options.find((o: CategoryFieldOption) => {
          if (typeof o === 'string') return o === raw;
          return String(o.value) === String(raw);
        });
        if (match && typeof match !== 'string') {
          display = String(match.label_ar ?? match.label ?? match.label_en ?? raw);
        }
      } else if (f.field_type === 'boolean') {
        display = raw === 'true' ? 'نعم' : 'لا';
      }
      rows.push({ key: f.field_key, label: f.label_ar, value: display });
    }
    return rows;
  }, [fields, w.details.fields]);

  const handleSubmit = async () => {
    if (!w.category || !w.city) return;
    setSubmitting(true);
    setError(null);

    try {
      const fd = new FormData();
      fd.append('category_id', String(w.category.id));
      fd.append('city_id', String(w.city.id));
      fd.append('pledge_accepted', '1');
      if (w.district) fd.append('district_id', String(w.district.id));
      if (w.districtFreeText) fd.append('district_name_free', w.districtFreeText);
      if (w.latLng) {
        fd.append('latitude', String(w.latLng.lat));
        fd.append('longitude', String(w.latLng.lng));
      }
      fd.append('title', w.details.title);
      fd.append('description', w.details.description);
      fd.append('price', w.details.isFree ? '0' : (w.details.price || '0'));
      fd.append('is_negotiable', w.details.isNegotiable ? '1' : '0');
      fd.append('is_free', w.details.isFree ? '1' : '0');
      fd.append('price_hidden', w.details.priceHidden ? '1' : '0');
      if (w.details.showPhonePublicly && w.details.phone) {
        fd.append('contact_phone', normalizePhone(w.details.phone));
      }
      if (w.details.whatsapp) fd.append('contact_whatsapp', normalizePhone(w.details.whatsapp));
      fd.append('show_phone_publicly', w.details.showPhonePublicly ? '1' : '0');

      const blobs = (typeof window !== 'undefined'
        ? (window as unknown as { __barqAdImageBlobs?: Map<string, File> }).__barqAdImageBlobs
        : undefined) ?? new Map<string, File>();
      w.images.filter(i => !i.removed && blobs.has(i.id))
        .forEach(i => fd.append('images[]', blobs.get(i.id)!));

      Object.entries(w.details.fields).forEach(([k, v]) => {
        if (v) fd.append(`fields[${k}]`, v);
      });

      const res = await createAd(fd);
      if (res.requires_payment) {
        router.push(`/ar/post-ad/pay/${res.ad.id}`);
      } else {
        w.reset();
        router.push(`/ar/ads/${res.ad.id}`);
      }
    } catch (e) {
      const msg = (e as { message?: string })?.message ?? 'فشل نشر الإعلان — حاول مرة أخرى';
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const tier: 'publish_fee_dealer' | 'publish_fee_individual' = user?.is_dealer
    ? 'publish_fee_dealer' : 'publish_fee_individual';
  const fee = (() => {
    const v = (w.category as unknown as Record<string, number | string | null | undefined>)?.[tier];
    return v === null || v === undefined ? 0 : Number(v);
  })();
  const isPaidCategory = fee > 0;

  const priceLabel = w.details.isFree
    ? 'مجاني'
    : w.details.priceHidden
      ? 'اتصل للسعر'
      : w.details.price
        ? `${Number(w.details.price).toLocaleString('ar-SA')} ر.س`
        : '—';

  const locationLine = [w.city?.name_ar, w.region?.name_ar].filter(Boolean).join('، ')
    + (w.district?.name_ar ? ` • ${w.district.name_ar}` : '')
    + (w.districtFreeText ? ` • ${w.districtFreeText}` : '');

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>✅</span>
        <div>
          <div className={styles.stepTitle}>المراجعة والدفع</div>
          <div className={styles.stepSub}>هكذا سيظهر إعلانك للمشترين</div>
        </div>
      </header>

      {/* Ad-detail-style preview */}
      <div className={styles.reviewPreview}>
        {/* Carousel */}
        <div className={styles.reviewCarousel}>
          {visibleImages.length > 0 ? (
            <>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={visibleImages[activeImg]?.previewUrl}
                alt={w.details.title || 'الإعلان'}
                className={styles.reviewMainImg}
              />
              {visibleImages.length > 1 && (
                <div className={styles.reviewThumbRow}>
                  {visibleImages.map((img, i) => (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      key={img.id}
                      src={img.previewUrl}
                      alt=""
                      className={`${styles.reviewThumb} ${activeImg === i ? styles.reviewThumbActive : ''}`}
                      onClick={() => setActiveImg(i)}
                    />
                  ))}
                </div>
              )}
            </>
          ) : (
            <div className={styles.reviewNoImg}>📷</div>
          )}
        </div>

        {/* Details card */}
        <div className={styles.reviewDetailsCard}>
          <h1 className={styles.reviewTitle}>{w.details.title || 'بدون عنوان'}</h1>

          <div className={styles.reviewMeta}>
            <span>📍 {locationLine || 'الموقع غير محدد'}</span>
            <span>🏷️ {w.category?.name_ar ?? ''}</span>
          </div>

          <div className={styles.reviewPriceTag}>
            {priceLabel}
            {w.details.isNegotiable && <span className={styles.negTag}>قابل للتفاوض</span>}
          </div>

          {fieldRows.length > 0 && (
            <div className={styles.reviewSpecs}>
              <strong>— المواصفات :</strong><br />
              {fieldRows.map(r => (
                <span key={r.key}>* {r.label}: {r.value}<br /></span>
              ))}
            </div>
          )}

          <div className={styles.reviewDesc}>
            {w.details.description || 'لا يوجد وصف'}
          </div>

          {w.details.showPhonePublicly && w.details.phone && (
            <div className={styles.reviewContact}>
              للتواصل:<span>{normalizePhone(w.details.phone)}</span>
            </div>
          )}
        </div>
      </div>

      {/* Fee breakdown */}
      <div style={{ marginTop: 16 }} className={styles.feeBreakdown}>
        <div className={pm.pmSectionTitle} style={{ marginBottom: 8 }}>
          <span className={pm.pmSectionTitleIcon}>💰</span>
          رسوم النشر
        </div>
        <div className={styles.feeRow}>
          <span>التسعيرة ({user?.is_dealer ? 'معرض/تاجر' : 'فرد'})</span>
          <span>{fee.toLocaleString('ar-SA')} ر.س</span>
        </div>
        <div className={styles.feeTotal}>
          <span>المجموع</span>
          <span>{fee.toLocaleString('ar-SA')} ر.س</span>
        </div>
        {isPaidCategory && (
          <p className={styles.feeWarn}>
            ⚠️ هذه الرسوم غير مستردة. تخصم لاحقاً من العمولة المستحقة عند البيع، حيث ينطبق ذلك.
          </p>
        )}
        {!isPaidCategory && (
          <p className={pm.pmHelp}>هذا التصنيف لا يتطلب رسوم نشر — سيتم نشر الإعلان مباشرة.</p>
        )}
      </div>

      {error && (
        <div style={{ marginTop: 12, color: '#fca5a5', fontSize: 13 }}>{error}</div>
      )}

      <WizardFooter
        forward={
          <button
            type="button"
            className={`${pm.pmBtn} ${pm.pmBtnPrimary}`}
            onClick={handleSubmit}
            disabled={submitting}
          >
            {submitting
              ? 'جارٍ الحفظ...'
              : isPaidCategory
                ? `💳 المتابعة للدفع (${fee.toLocaleString('ar-SA')} ر.س)`
                : '🚀 نشر الإعلان'}
          </button>
        }
      />
    </div>
  );
}
