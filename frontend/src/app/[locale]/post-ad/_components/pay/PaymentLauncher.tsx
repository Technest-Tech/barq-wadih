'use client';

import { useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { confirmAdPayment, initAdPayment } from '@/lib/api/payments';

type Props = {
  adId: number;
  amount: number;
  /** Called after the mock confirms and the ad transitions to active. */
  onPaid: () => void;
};

/**
 * Apple Pay / Mada buttons. Both go through the same /payment/init →
 * /payment/confirm flow under the mock driver. When the real Moyasar driver
 * is wired up, the buttons keep working as-is — only the redirect_url
 * destination changes (PSP-hosted instead of our own confirm).
 */
export function PaymentLauncher({ adId, amount, onPaid }: Props) {
  const [loading, setLoading] = useState<null | 'apple' | 'mada'>(null);
  const [error, setError] = useState<string | null>(null);

  const launch = async (method: 'apple' | 'mada') => {
    setLoading(method);
    setError(null);
    try {
      const init = await initAdPayment(adId);
      // Mock driver returns our own confirm URL — call it directly so the
      // user never leaves the page in dev. With real Moyasar this would be
      // window.location.assign(init.intent.redirect_url) instead.
      await confirmAdPayment(adId, init.intent.reference);
      onPaid();
    } catch (e) {
      const msg = (e as { message?: string })?.message ?? 'فشل الدفع — حاول مرة أخرى';
      setError(msg);
    } finally {
      setLoading(null);
    }
  };

  return (
    <div>
      <div className={styles.payRow}>
        <button
          type="button"
          className={`${styles.payBtn} ${styles.payBtnApple}`}
          disabled={loading !== null}
          onClick={() => launch('apple')}
        >
          {loading === 'apple' ? '...' : '🍎 الدفع عبر Apple Pay'}
        </button>
        <button
          type="button"
          className={`${styles.payBtn} ${styles.payBtnMada}`}
          disabled={loading !== null}
          onClick={() => launch('mada')}
        >
          {loading === 'mada' ? '...' : '💳 الدفع عبر مدى'}
        </button>
      </div>
      <p className={pm.pmHelp} style={{ marginTop: 10 }}>
        بالنقر على زر الدفع توافق على دفع مبلغ {amount.toLocaleString('ar-SA')} ر.س. هذه الرسوم غير مستردة.
      </p>
      {error && <p style={{ color: '#fca5a5', fontSize: 12.5, marginTop: 8 }}>{error}</p>}
    </div>
  );
}
