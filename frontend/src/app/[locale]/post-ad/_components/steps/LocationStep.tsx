'use client';

import dynamic from 'next/dynamic';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { createAd } from '@/lib/api/ads';
import { fetchRegions, fetchCities, type Region, type City } from '@/lib/api/regions';
import { fetchDistrictsByCity, type District } from '@/lib/api/districts';
import { normalizePhone, usePostAdWizard } from '@/store/postAdWizard.store';
import { SearchableList } from '../shared/SearchableList';
import { WizardFooter } from '../WizardFooter';

// Leaflet is client-only — its `window` access breaks SSR.
const LeafletMap = dynamic(() => import('./MapStepLeaflet').then((m) => m.MapStepLeaflet), {
  ssr: false,
  loading: () => (
    <div
      className={styles.mapWrap}
      style={{ display: 'grid', placeItems: 'center', color: 'var(--admin-text-muted)' }}
    >
      جارٍ تحميل الخريطة...
    </div>
  ),
});

/**
 * Combined location + submit step — mirrors the mobile app's final screen:
 * region → city → district (optional) → map pin (optional) → fees → publish.
 */
export function LocationStep() {
  const router = useRouter();
  const w = usePostAdWizard();

  const [regions, setRegions] = useState<Region[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [districts, setDistricts] = useState<District[]>([]);
  const [loadingRegions, setLoadingRegions] = useState(true);
  const [loadingCities, setLoadingCities] = useState(false);
  const [loadingDistricts, setLoadingDistricts] = useState(false);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchRegions()
      .then(setRegions)
      .catch(console.error)
      .finally(() => setLoadingRegions(false));
  }, []);

  useEffect(() => {
    if (!w.region) {
      setCities([]);
      return;
    }
    setLoadingCities(true);
    fetchCities(w.region.slug)
      .then(setCities)
      .catch(console.error)
      .finally(() => setLoadingCities(false));
  }, [w.region]);

  useEffect(() => {
    if (!w.city) {
      setDistricts([]);
      return;
    }
    setLoadingDistricts(true);
    fetchDistrictsByCity(w.city.id)
      .then(setDistricts)
      .catch(console.error)
      .finally(() => setLoadingDistricts(false));
  }, [w.city]);

  const useFreeTextDistrict = !loadingDistricts && !!w.city && districts.length === 0;

  // Publishing is free; the flat commission is owed only after the sale.
  const commission = (() => {
    const cat = w.category as unknown as Record<
      string,
      number | string | null | boolean | undefined
    >;
    if (cat?.['is_free']) return 0;
    const v = cat?.['deferred_commission_individual'];
    return v === null || v === undefined ? 0 : Number(v);
  })();
  const hasCommission = commission > 0;

  const mapFallback: [number, number] = [
    Number(w.city?.latitude ?? 24.7136),
    Number(w.city?.longitude ?? 46.6753),
  ];

  const useMyLocation = () => {
    if (typeof navigator === 'undefined' || !('geolocation' in navigator)) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => w.setLatLng({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => {},
      { enableHighAccuracy: true, timeout: 8000 }
    );
  };

  const handleSubmit = async () => {
    if (!w.category || !w.city) return;
    setSubmitting(true);
    setError(null);
    try {
      const fd = new FormData();
      fd.append('seller_type', 'individual');
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
      // Price required for "fixed" and "على السوم"; omitted for "عند الاتصال".
      if (!w.details.priceHidden && w.details.price.trim()) {
        fd.append('price', w.details.price.trim());
      }
      fd.append('is_negotiable', w.details.isNegotiable ? '1' : '0');
      fd.append('is_free', '0');
      fd.append('price_hidden', w.details.priceHidden ? '1' : '0');
      if (w.details.showPhonePublicly && w.details.phone) {
        fd.append('contact_phone', normalizePhone(w.details.phone));
      }
      fd.append('show_phone_publicly', w.details.showPhonePublicly ? '1' : '0');

      Object.entries(w.details.fields).forEach(([k, v]) => {
        if (v && String(v).trim()) fd.append(`fields[${k}]`, String(v).trim());
      });

      const blobs =
        (typeof window !== 'undefined'
          ? (window as unknown as { __barqAdImageBlobs?: Map<string, File> }).__barqAdImageBlobs
          : undefined) ?? new Map<string, File>();
      w.images
        .filter((i) => !i.removed && blobs.has(i.id))
        .forEach((i) => fd.append('images[]', blobs.get(i.id)!));

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

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>📍</span>
        <div>
          <div className={styles.stepTitle}>موقع الإعلان</div>
          <div className={styles.stepSub}>اختر المنطقة ثم المدينة، والحي اختياري</div>
        </div>
      </header>

      {/* ── Region ─────────────────────────────────────────────────────────── */}
      {!w.region ? (
        loadingRegions ? (
          <div className={styles.loadingWrap}>
            <div className={styles.spinner} />
          </div>
        ) : (
          <SearchableList
            items={regions.map((r) => ({
              id: r.id,
              label: r.name_ar,
              meta: `${r.cities_count} مدينة`,
              icon: '📍',
            }))}
            selectedId={null}
            placeholder="ابحث عن منطقة..."
            onSelect={(item) => {
              const r = regions.find((x) => x.id === item.id) ?? null;
              w.setRegion(r);
            }}
          />
        )
      ) : (
        <SelectedRow label="المنطقة" value={w.region.name_ar} onChange={() => w.setRegion(null)} />
      )}

      {/* ── City ───────────────────────────────────────────────────────────── */}
      {w.region &&
        (!w.city ? (
          loadingCities ? (
            <div className={styles.loadingWrap}>
              <div className={styles.spinner} />
            </div>
          ) : (
            <SearchableList
              items={cities.map((c) => ({
                id: c.id,
                label: c.name_ar,
                meta: c.districts_count ? `${c.districts_count} حي` : undefined,
                icon: '🏘️',
              }))}
              selectedId={null}
              placeholder="ابحث عن مدينة..."
              emptyText="لا توجد مدن مطابقة — جرّب اسماً آخر"
              onSelect={(item) => {
                const c = cities.find((x) => x.id === item.id) ?? null;
                w.setCity(c);
              }}
            />
          )
        ) : (
          <SelectedRow label="المدينة" value={w.city.name_ar} onChange={() => w.setCity(null)} />
        ))}

      {/* ── District + Map + Fees + Submit (once a city is chosen) ──────────── */}
      {w.city && (
        <>
          {loadingDistricts ? (
            <div className={styles.loadingWrap}>
              <div className={styles.spinner} />
            </div>
          ) : useFreeTextDistrict ? (
            <div className={pm.pmField} style={{ marginTop: 12 }}>
              <label className={pm.pmLabel}>الحي (اختياري)</label>
              <input
                className={pm.pmInput}
                placeholder="مثال: حي الياسمين"
                maxLength={120}
                value={w.districtFreeText}
                onChange={(e) => w.setDistrictFreeText(e.target.value)}
              />
            </div>
          ) : (
            <div style={{ marginTop: 12 }}>
              <div className={pm.pmLabel} style={{ marginBottom: 6 }}>
                الحي (اختياري)
              </div>
              <SearchableList
                items={districts.map((d) => ({ id: d.id, label: d.name_ar, icon: '🏘️' }))}
                selectedId={w.district?.id ?? null}
                placeholder="ابحث عن حي..."
                emptyText="لا توجد أحياء مطابقة"
                onSelect={(item) => {
                  const d = districts.find((x) => x.id === item.id) ?? null;
                  w.setDistrict(w.district?.id === item.id ? null : d);
                }}
              />
            </div>
          )}

          {/* Map pin (optional) */}
          <div style={{ marginTop: 16 }}>
            <div className={pm.pmLabel} style={{ marginBottom: 6 }}>
              الموقع على الخريطة (اختياري)
            </div>
            <p className={styles.mapHint}>
              يساعد المشترين على تقدير المسافة. لن يظهر العنوان الدقيق علناً.
            </p>
            <div className={styles.mapWrap}>
              <LeafletMap
                center={w.latLng ? [w.latLng.lat, w.latLng.lng] : mapFallback}
                marker={w.latLng ? [w.latLng.lat, w.latLng.lng] : null}
                onChange={(lat, lng) => w.setLatLng({ lat, lng })}
              />
            </div>
            <div className={styles.mapBtnRow}>
              <button
                type="button"
                className={`${pm.pmBtn} ${pm.pmBtnGhost}`}
                onClick={useMyLocation}
              >
                📡 استخدم موقعي الحالي
              </button>
              {w.latLng && (
                <button
                  type="button"
                  className={`${pm.pmBtn} ${pm.pmBtnGhost}`}
                  onClick={() => w.setLatLng(null)}
                >
                  ✕ مسح
                </button>
              )}
            </div>
          </div>

          {/* Fees */}
          <div style={{ marginTop: 16 }} className={styles.feeBreakdown}>
            <div className={pm.pmSectionTitle} style={{ marginBottom: 8 }}>
              <span className={pm.pmSectionTitleIcon}>💰</span>
              الرسوم والعمولة
            </div>
            <div className={styles.feeRow}>
              <span>رسوم النشر</span>
              <span>مجاني</span>
            </div>
            <div className={styles.feeRow}>
              <span>عمولة البيع (تُدفع بعد إتمام البيع)</span>
              <span>{hasCommission ? `${commission.toLocaleString('ar-SA')} ر.س` : 'مجاني'}</span>
            </div>
            {hasCommission ? (
              <p className={styles.feeWarn}>
                ℹ️ النشر مجاني. عند إتمام البيع تُستحق عمولة ثابتة{' '}
                {commission.toLocaleString('ar-SA')} ر.س (شاملة ضريبة القيمة المضافة).
              </p>
            ) : (
              <p className={pm.pmHelp}>هذا التصنيف مجاني بالكامل — لا رسوم نشر ولا عمولة.</p>
            )}
          </div>
        </>
      )}

      {error && <div style={{ marginTop: 12, color: '#fca5a5', fontSize: 13 }}>{error}</div>}

      <WizardFooter
        forward={
          <button
            type="button"
            className={`${pm.pmBtn} ${pm.pmBtnPrimary}`}
            onClick={handleSubmit}
            disabled={submitting || !w.city}
          >
            {submitting ? 'جارٍ النشر...' : '🚀 نشر الإعلان'}
          </button>
        }
      />
    </div>
  );
}

function SelectedRow({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: () => void;
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 8,
        padding: '10px 14px',
        marginTop: 10,
        borderRadius: 10,
        border: '1px solid rgba(99,102,241,0.25)',
        background: 'rgba(99,102,241,0.08)',
      }}
    >
      <span style={{ fontSize: 14, color: '#c7d2fe' }}>
        <strong>{label}:</strong> {value}
      </span>
      <button
        type="button"
        onClick={onChange}
        style={{
          background: 'transparent',
          border: 'none',
          color: '#a5b4fc',
          fontWeight: 700,
          cursor: 'pointer',
          fontSize: 13,
        }}
      >
        تغيير
      </button>
    </div>
  );
}
