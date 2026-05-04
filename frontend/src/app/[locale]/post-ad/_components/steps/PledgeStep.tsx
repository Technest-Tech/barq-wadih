'use client';

import styles from '../../post-ad.module.css';
import { usePostAdWizard } from '@/store/postAdWizard.store';
import { PLEDGE_BODY, PLEDGE_QURAN } from '../shared/PledgeText';
import { WizardFooter } from '../WizardFooter';

/**
 * Step 2 — Binding fees pledge. Continue is disabled until the checkbox
 * is ticked. Persists to wizard state and ultimately to ads.pledge_accepted.
 */
export function PledgeStep() {
  const accepted = usePostAdWizard(s => s.pledgeAccepted);
  const setAccepted = usePostAdWizard(s => s.setPledgeAccepted);

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>🤝</span>
        <div>
          <div className={styles.stepTitle}>تعهّد المعلن</div>
          <div className={styles.stepSub}>اقرأ الميثاق ثم وافق للمتابعة</div>
        </div>
      </header>

      <div className={styles.pledgeBox}>
        <div className={styles.pledgeQuran}>{PLEDGE_QURAN}</div>
        {PLEDGE_BODY}
      </div>

      <label className={styles.pledgeCheckbox}>
        <input
          type="checkbox"
          checked={accepted}
          onChange={(e) => setAccepted(e.target.checked)}
        />
        <span>أوافق على هذا التعهّد وأقسم بالله أن المعلومات المنشورة صحيحة، وأن أدفع الرسوم المستحقة وفق الشروط أعلاه.</span>
      </label>

      <WizardFooter />
    </div>
  );
}
