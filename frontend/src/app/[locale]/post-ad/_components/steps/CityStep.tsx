'use client';

import { useEffect, useState } from 'react';
import styles from '../../post-ad.module.css';
import { fetchCities, type City } from '@/lib/api/regions';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { SearchableList } from '../shared/SearchableList';
import { WizardFooter } from '../WizardFooter';

export function CityStep() {
  const region = usePostAdWizard(s => s.region);
  const city   = usePostAdWizard(s => s.city);
  const setCity = usePostAdWizard(s => s.setCity);
  const goNext = usePostAdWizard(s => s.goNext);

  const [cities, setCities] = useState<City[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!region) return;
    setLoading(true);
    fetchCities(region.slug).then(setCities).catch(console.error).finally(() => setLoading(false));
  }, [region]);

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>🏙️</span>
        <div>
          <div className={styles.stepTitle}>اختر المدينة</div>
          <div className={styles.stepSub}>{region?.name_ar ?? ''}</div>
        </div>
      </header>

      {loading ? (
        <div className={styles.loadingWrap}><div className={styles.spinner} /></div>
      ) : (
        <SearchableList
          items={cities.map(c => ({
            id: c.id,
            label: c.name_ar,
            meta: c.districts_count ? `${c.districts_count} حي` : undefined,
            icon: '🏘️',
          }))}
          selectedId={city?.id ?? null}
          placeholder="ابحث عن مدينة..."
          emptyText="لا توجد مدن مطابقة — جرّب اسماً آخر"
          onSelect={(item) => {
            const c = cities.find(x => x.id === item.id) ?? null;
            setCity(c);
            if (c) setTimeout(goNext, 120);
          }}
        />
      )}

      <WizardFooter />
    </div>
  );
}
