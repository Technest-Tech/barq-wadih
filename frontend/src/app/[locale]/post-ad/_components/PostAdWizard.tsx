'use client';

import { useEffect, useState } from 'react';
import styles from '../post-ad.module.css';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { WizardStepper } from './WizardStepper';
import { PledgeStep } from './steps/PledgeStep';
import { CategoryStep } from './steps/CategoryStep';
import { DetailsStep } from './steps/DetailsStep';
import { ImagesStep } from './steps/ImagesStep';
import { LocationStep } from './steps/LocationStep';

/**
 * PostAdWizard — root client component mounted under /post-ad. The Zustand
 * store uses `skipHydration` so SSR and the first client paint always match;
 * we trigger rehydration in this effect, then render the step UI.
 */
export function PostAdWizard() {
  const step = usePostAdWizard((s) => s.step);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    // Zustand v5's rehydrate() returns Promise<void> | void depending on whether
    // the storage is async — localStorage is sync, so we resolve through
    // Promise.resolve() to handle both shapes uniformly.
    Promise.resolve(usePostAdWizard.persist.rehydrate()).finally(() => setHydrated(true));
  }, []);

  if (!hydrated) {
    return (
      <div className={styles.shell}>
        <div className={styles.loadingWrap}>
          <div className={styles.spinner} />
        </div>
      </div>
    );
  }

  return (
    <div className={styles.shell}>
      <WizardStepper />
      <div className={styles.card}>
        {step === 'pledge' && <PledgeStep />}
        {step === 'category' && <CategoryStep />}
        {step === 'details' && <DetailsStep />}
        {step === 'images' && <ImagesStep />}
        {step === 'location' && <LocationStep />}
      </div>
    </div>
  );
}
