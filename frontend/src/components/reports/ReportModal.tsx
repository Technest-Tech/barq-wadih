'use client';

import React, { useState, useEffect } from 'react';
import apiClient from '@/lib/api/client';
import ENDPOINTS from '@/lib/api/endpoints';
import styles from './ReportModal.module.css';

interface ReportReason {
  value: string;
  label: string;
}

interface ReportModalProps {
  adId: number;
  onClose: () => void;
}

export default function ReportModal({ adId, onClose }: ReportModalProps) {
  const [reasons, setReasons]       = useState<ReportReason[]>([]);
  const [selected, setSelected]     = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading]       = useState(false);
  const [success, setSuccess]       = useState(false);
  const [error, setError]           = useState('');

  useEffect(() => {
    apiClient
      .get<ReportReason[]>(ENDPOINTS.REPORT_REASONS)
      .then((res) => setReasons(res.data ?? []))
      .catch(() => {});
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!selected) { setError('اختر سبب البلاغ'); return; }

    setLoading(true);
    setError('');

    try {
      await apiClient.post(ENDPOINTS.AD_REPORT(adId), {
        reason: selected,
        description: description.trim() || undefined,
      });
      setSuccess(true);
      setTimeout(onClose, 2000);
    } catch (err: unknown) {
      const msg = (err as { message?: string })?.message;
      setError(msg ?? 'حدث خطأ، حاول مجدداً');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className={styles.overlay}
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className={styles.modal} role="dialog" aria-modal="true">
        <button className={styles.closeBtn} onClick={onClose} aria-label="إغلاق">✕</button>

        {success ? (
          <div className={styles.successState}>
            <div className={styles.checkmark}>✓</div>
            <p>تم إرسال البلاغ</p>
            <small>سيتم مراجعته من قِبَل فريق الإشراف</small>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className={styles.form}>
            <h2 className={styles.title}>الإبلاغ عن الإعلان</h2>

            <div className={styles.reasonsList}>
              {reasons.map((r) => (
                <label key={r.value} className={styles.reasonItem}>
                  <input
                    type="radio"
                    name="reason"
                    value={r.value}
                    checked={selected === r.value}
                    onChange={() => setSelected(r.value)}
                    className={styles.radio}
                  />
                  <span>{r.label}</span>
                </label>
              ))}
            </div>

            <div className={styles.field}>
              <label className={styles.label}>تفاصيل إضافية (اختياري)</label>
              <textarea
                className={styles.textarea}
                placeholder="اشرح المشكلة بمزيد من التفاصيل..."
                value={description}
                onChange={(e) => setDescription(e.target.value.slice(0, 1000))}
                rows={3}
              />
            </div>

            {error && <p className={styles.error}>{error}</p>}

            <button
              type="submit"
              className={styles.submitBtn}
              disabled={loading || !selected}
            >
              {loading ? 'جارٍ الإرسال...' : 'إرسال البلاغ'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
