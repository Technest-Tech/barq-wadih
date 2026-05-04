'use client';

import { STEP_ORDER, type WizardStep, isStepComplete, usePostAdWizard } from '@/store/postAdWizard.store';
import styles from '../post-ad.module.css';

const STEP_LABELS: Record<WizardStep, { label: string; icon: string }> = {
  category:  { label: 'التصنيف',     icon: '📂' },
  pledge:    { label: 'التعهّد',      icon: '🤝' },
  region:    { label: 'المنطقة',     icon: '🗺️' },
  city:      { label: 'المدينة',     icon: '🏙️' },
  district:  { label: 'الحي',        icon: '🏘️' },
  map:       { label: 'الخريطة',     icon: '📍' },
  images:    { label: 'الصور',       icon: '📸' },
  details:   { label: 'التفاصيل',    icon: '📝' },
  review:    { label: 'المراجعة والدفع', icon: '✅' },
};

/**
 * Sticky stepper at the top of the wizard. Steps the user has completed are
 * clickable; future steps are disabled until prior gates pass.
 */
export function WizardStepper() {
  const state = usePostAdWizard();

  return (
    <nav className={styles.stepper} aria-label="مراحل نشر الإعلان">
      {STEP_ORDER.map((s, i) => {
        const meta = STEP_LABELS[s];
        const isActive = state.step === s;
        const reached = STEP_ORDER.indexOf(state.step) > i;
        const completed = reached && isStepComplete(state, s);
        // Allow jump-back to any completed step OR forward to the next
        // step if all previous gates pass.
        const canJumpTo = completed || isActive
          || STEP_ORDER.slice(0, i).every(prev => isStepComplete(state, prev));

        return (
          <button
            key={s}
            type="button"
            className={`${styles.stepBtn} ${isActive ? styles.active : ''} ${completed ? styles.done : ''}`}
            disabled={!canJumpTo}
            onClick={() => canJumpTo && state.setStep(s)}
          >
            <span className={styles.stepIdx}>{completed ? '✓' : i + 1}</span>
            <span>{meta.icon}</span>
            <span>{meta.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
