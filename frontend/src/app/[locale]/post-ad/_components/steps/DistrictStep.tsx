'use client';

import { useEffect, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { fetchDistrictsByCity, type District } from '@/lib/api/districts';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { SearchableList } from '../shared/SearchableList';
import { WizardFooter } from '../WizardFooter';

/**
 * Step 5 — District. If the city has seeded districts we render a searchable
 * list; otherwise the user types a free-text district name. The wizard's
 * canAdvance gate accepts either signal.
 */
export function DistrictStep() {
  const city = usePostAdWizard(s => s.city);
  const district = usePostAdWizard(s => s.district);
  const setDistrict = usePostAdWizard(s => s.setDistrict);
  const districtFreeText = usePostAdWizard(s => s.districtFreeText);
  const setDistrictFreeText = usePostAdWizard(s => s.setDistrictFreeText);
  const goNext = usePostAdWizard(s => s.goNext);

  const [districts, setDistricts] = useState<District[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!city) return;
    setLoading(true);
    fetchDistrictsByCity(city.id)
      .then(setDistricts)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [city]);

  const useFreeText = !loading && districts.length === 0;

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>🏘️</span>
        <div>
          <div className={styles.stepTitle}>الحي</div>
          <div className={styles.stepSub}>
            {useFreeText ? 'اكتب اسم الحي يدوياً' : `${city?.name_ar ?? ''}`}
          </div>
        </div>
      </header>

      {loading ? (
        <div className={styles.loadingWrap}><div className={styles.spinner} /></div>
      ) : useFreeText ? (
        <div className={pm.pmField}>
          <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>اسم الحي</label>
          <input
            className={pm.pmInput}
            placeholder="مثال: حي الياسمين"
            maxLength={120}
            value={districtFreeText}
            onChange={(e) => setDistrictFreeText(e.target.value)}
          />
          <span className={pm.pmHelp}>لم نضف أحياء هذه المدينة بعد — يمكنك كتابتها يدوياً.</span>
        </div>
      ) : (
        <SearchableList
          items={districts.map(d => ({ id: d.id, label: d.name_ar, icon: '🏘️' }))}
          selectedId={district?.id ?? null}
          placeholder="ابحث عن حي..."
          emptyText="لا توجد أحياء مطابقة — جرّب اسماً آخر أو انتقل للخريطة"
          onSelect={(item) => {
            const d = districts.find(x => x.id === item.id) ?? null;
            setDistrict(d);
            if (d) setTimeout(goNext, 120);
          }}
        />
      )}

      <WizardFooter />
    </div>
  );
}
