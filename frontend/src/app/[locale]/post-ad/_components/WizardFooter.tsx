'use client';

import pm from '@/styles/premium.module.css';
import styles from '../post-ad.module.css';
import { canAdvance, STEP_ORDER, usePostAdWizard } from '@/store/postAdWizard.store';

type Props = {
  /** Override the default forward button — used by Review step to swap in submit/pay. */
  forward?: React.ReactNode;
  /** Custom click handler for the forward button. Defaults to goNext. */
  onForward?: () => void;
  forwardLabel?: string;
};

/**
 * Sticky footer with Back / Next buttons, gated on `canAdvance(currentStep)`.
 */
export function WizardFooter({ forward, onForward, forwardLabel = 'التالي ←' }: Props) {
  const state = usePostAdWizard();
  const idx = STEP_ORDER.indexOf(state.step);
  const isFirst = idx === 0;
  const isLast = idx === STEP_ORDER.length - 1;
  const canGo = canAdvance(state, state.step);

  return (
    <div className={styles.footer}>
      <button
        type="button"
        className={`${pm.pmBtn} ${pm.pmBtnGhost}`}
        onClick={state.goBack}
        disabled={isFirst}
      >
        → السابق
      </button>
      <span className={styles.footerProgress}>
        خطوة {idx + 1} من {STEP_ORDER.length}
      </span>
      {forward ?? (
        <button
          type="button"
          className={`${pm.pmBtn} ${pm.pmBtnPrimary}`}
          onClick={onForward ?? state.goNext}
          disabled={!canGo || isLast}
        >
          {forwardLabel}
        </button>
      )}
    </div>
  );
}
