'use client';

import React, { useState } from 'react';
import StarRating from './StarRating';
import { submitRating } from '@/lib/api/ratings';
import styles from './RatingModal.module.css';

interface RatingModalProps {
  adId: number;
  sellerName: string;
  onClose: () => void;
  onSuccess: () => void;
}

export default function RatingModal({
  adId,
  sellerName,
  onClose,
  onSuccess,
}: RatingModalProps) {
  const [stars, setStars]       = useState(0);
  const [comment, setComment]   = useState('');
  const [pledge, setPledge]     = useState(false);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState('');
  const [success, setSuccess]   = useState(false);

  const MAX_COMMENT = 500;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (stars === 0) { setError('اختر عدد النجوم'); return; }
    if (!pledge)     { setError('يجب الموافقة على التعهد'); return; }

    setLoading(true);
    setError('');

    try {
      await submitRating(adId, {
        stars,
        comment: comment.trim() || undefined,
        pledge_accepted: true,
      });
      setSuccess(true);
      setTimeout(() => { onSuccess(); onClose(); }, 1500);
    } catch (err: unknown) {
      const msg = (err as { message?: string })?.message;
      setError(msg ?? 'حدث خطأ، حاول مجدداً');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className={styles.overlay} onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className={styles.modal} role="dialog" aria-modal="true">
        <button className={styles.closeBtn} onClick={onClose} aria-label="إغلاق">✕</button>

        {success ? (
          <div className={styles.successState}>
            <div className={styles.checkmark}>✓</div>
            <p>شكراً لتقييمك!</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className={styles.form}>
            <h2 className={styles.title}>تقييم البائع</h2>
            <p className={styles.subtitle}>تقييمك لـ <strong>{sellerName}</strong></p>

            {/* Stars */}
            <div className={styles.starsRow}>
              <StarRating
                value={stars}
                size="lg"
                interactive
                onChange={setStars}
              />
            </div>
            <p className={styles.starsLabel}>
              {stars === 0 && 'اختر تقييمك'}
              {stars === 1 && 'سيء جداً'}
              {stars === 2 && 'سيء'}
              {stars === 3 && 'مقبول'}
              {stars === 4 && 'جيد'}
              {stars === 5 && 'ممتاز'}
            </p>

            {/* Comment */}
            <div className={styles.field}>
              <label className={styles.label}>تعليق (اختياري)</label>
              <textarea
                className={styles.textarea}
                placeholder="شارك تجربتك مع هذا البائع..."
                value={comment}
                onChange={(e) => setComment(e.target.value.slice(0, MAX_COMMENT))}
                rows={3}
              />
              <span className={styles.charCount}>
                {comment.length} / {MAX_COMMENT}
              </span>
            </div>

            {/* Pledge */}
            <label className={styles.pledgeRow}>
              <input
                type="checkbox"
                checked={pledge}
                onChange={(e) => setPledge(e.target.checked)}
                className={styles.checkbox}
              />
              <span className={styles.pledgeText}>
                أتعهد بأن هذا التقييم صادق وعادل ويعكس تجربتي الحقيقية
              </span>
            </label>

            {error && <p className={styles.error}>{error}</p>}

            <button
              type="submit"
              className={styles.submitBtn}
              disabled={loading || stars === 0}
            >
              {loading ? 'جارٍ الإرسال...' : 'إرسال التقييم'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
