'use client';

import { useEffect, useState } from 'react';
import styles from '../../post-ad.module.css';
import { fetchRegions, type Region } from '@/lib/api/regions';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { SearchableList } from '../shared/SearchableList';
import { WizardFooter } from '../WizardFooter';

export function RegionStep() {
  const region = usePostAdWizard(s => s.region);
  const setRegion = usePostAdWizard(s => s.setRegion);
  const goNext = usePostAdWizard(s => s.goNext);

  const [regions, setRegions] = useState<Region[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchRegions().then(setRegions).catch(console.error).finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>🗺️</span>
        <div>
          <div className={styles.stepTitle}>اختر المنطقة</div>
          <div className={styles.stepSub}>المنطقة الإدارية التي يقع فيها الإعلان</div>
        </div>
      </header>

      {loading ? (
        <div className={styles.loadingWrap}><div className={styles.spinner} /></div>
      ) : (
        <SearchableList
          items={regions.map(r => ({ id: r.id, label: r.name_ar, meta: `${r.cities_count} مدينة`, icon: '📍' }))}
          selectedId={region?.id ?? null}
          placeholder="ابحث عن منطقة..."
          onSelect={(item) => {
            const r = regions.find(x => x.id === item.id) ?? null;
            setRegion(r);
            if (r) setTimeout(goNext, 120);
          }}
        />
      )}

      <WizardFooter />
    </div>
  );
}
