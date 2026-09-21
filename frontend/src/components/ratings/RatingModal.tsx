'use client';

import React, { useState } from 'react';
import StarRating from './StarRating';
import { submitRating, submitSellerRating, type Rating } from '@/lib/api/ratings';
import styles from './RatingModal.module.css';

/**
 * A review is written either against one listing (from the ad page) or against
 * the seller themselves (from their profile). Both land in the same list and
 * feed the same average — only the endpoint differs.
 */
export type RatingTarget =
  | { kind: 'ad'; adId: number }
  | { kind: 'seller'; userId: number };

interface RatingModalProps {
  target: RatingTarget;
  sellerName: string;
  onClose: () => void;
  onSuccess: (rating: Rating) => void;
}

export default function RatingModal({
  target,
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

    const payload = {
      stars,
      comment: comment.trim() || undefined,
      pledge_accepted: true as const,
    };

    try {
      const rating = target.kind === 'ad'
        ? await submitRating(target.adId, payload)
        : await submitSellerRating(target.userId, payload);
      setSuccess(true);
      setTimeout(() => { onSuccess(rating); onClose(); }, 1500);
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
