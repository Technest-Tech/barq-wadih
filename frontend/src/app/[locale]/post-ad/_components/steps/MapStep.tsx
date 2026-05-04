'use client';

import dynamic from 'next/dynamic';
import { useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { WizardFooter } from '../WizardFooter';

// Leaflet must be client-only — its `window` access breaks SSR.
const LeafletMap = dynamic(() => import('./MapStepLeaflet').then(m => m.MapStepLeaflet), {
  ssr: false,
  loading: () => <div className={styles.mapWrap} style={{ display: 'grid', placeItems: 'center', color: 'var(--admin-text-muted)' }}>جارٍ تحميل الخريطة...</div>,
});

/**
 * Step 6 — Map pin. Initial centre = city.latitude/longitude (fallback to
 * Riyadh). The user drags the pin to set ad-level lat/lng, or hits "Use my
 * location" for the geolocation fallback.
 */
export function MapStep() {
  const city = usePostAdWizard(s => s.city);
  const latLng = usePostAdWizard(s => s.latLng);
  const setLatLng = usePostAdWizard(s => s.setLatLng);

  const [geoErr, setGeoErr] = useState<string | null>(null);

  const useMyLocation = () => {
    if (!('geolocation' in navigator)) {
      setGeoErr('المتصفح لا يدعم خدمة تحديد الموقع.');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLatLng({ lat: pos.coords.latitude, lng: pos.coords.longitude });
        setGeoErr(null);
      },
      (err) => setGeoErr(err.message || 'تعذّر تحديد الموقع'),
      { enableHighAccuracy: true, timeout: 8000 }
    );
  };

  const fallback: [number, number] = [
    Number(city?.latitude ?? 24.7136),
    Number(city?.longitude ?? 46.6753),
  ];

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>📍</span>
        <div>
          <div className={styles.stepTitle}>حدّد الموقع على الخريطة</div>
          <div className={styles.stepSub}>اسحب الدبوس إلى الموقع الدقيق</div>
        </div>
      </header>

      <p className={styles.mapHint}>
        الموقع الذي تختاره يُساعد المشترين على تقدير المسافة. لن يظهر العنوان الدقيق علناً.
      </p>

      <div className={styles.mapWrap}>
        <LeafletMap
          center={latLng ? [latLng.lat, latLng.lng] : fallback}
          marker={latLng ? [latLng.lat, latLng.lng] : null}
          onChange={(lat, lng) => setLatLng({ lat, lng })}
        />
      </div>

      <div className={styles.mapBtnRow}>
        <button type="button" className={`${pm.pmBtn} ${pm.pmBtnGhost}`} onClick={useMyLocation}>
          📡 استخدم موقعي الحالي
        </button>
        {latLng && (
          <button type="button" className={`${pm.pmBtn} ${pm.pmBtnGhost}`} onClick={() => setLatLng(null)}>
            ✕ مسح
          </button>
        )}
      </div>

      {geoErr && <p style={{ color: '#fca5a5', fontSize: 12, marginTop: 8 }}>{geoErr}</p>}
      {latLng && (
        <div className={styles.mapCoords}>
          {latLng.lat.toFixed(5)}, {latLng.lng.toFixed(5)}
        </div>
      )}

      <WizardFooter />
    </div>
  );
}
