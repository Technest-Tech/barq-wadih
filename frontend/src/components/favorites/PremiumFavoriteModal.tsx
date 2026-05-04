'use client';

import React, { useState } from 'react';
import { toggleFavorite } from '@/lib/api/favorites';
import styles from './PremiumFavoriteModal.module.css';

interface PremiumFavoriteModalProps {
  adId: number;
  adTitle: string;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (isFavorited: boolean) => void;
}

export default function PremiumFavoriteModal({
  adId,
  adTitle,
  isOpen,
  onClose,
  onSuccess,
}: PremiumFavoriteModalProps) {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');

  if (!isOpen) return null;

  async function handleAddFavorite() {
    setLoading(true);
    setError('');
    try {
      const res = await toggleFavorite(adId);
      setSuccess(true);
      onSuccess(res.is_favorited);
      setTimeout(() => {
        onClose();
        setSuccess(false);
      }, 1800);
    } catch {
      setError('حدث خطأ، حاول مجدداً');
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
            <div className={styles.heartPop}>♥</div>
            <h3 className={styles.successTitle}>تمت الإضافة للمفضلة!</h3>
            <p className={styles.successSub}>يمكنك مشاهدة إعلاناتك المفضلة في أي وقت</p>
          </div>
        ) : (
          <div className={styles.content}>
            {/* Premium Badge */}
            <div className={styles.premiumBadge}>
              <span className={styles.crownIcon}>♛</span>
              <span>ميزة مميزة</span>
            </div>

            {/* Heart Icon */}
            <div className={styles.heartIcon}>♥</div>

            <h2 className={styles.title}>أضف للمفضلة</h2>
            <p className={styles.adName}>{adTitle}</p>

            {/* Benefits */}
            <ul className={styles.benefits}>
              <li>
                <span className={styles.checkIcon}>✓</span>
                <span>احفظ الإعلانات التي تهمك</span>
              </li>
              <li>
                <span className={styles.checkIcon}>✓</span>
                <span>ارجع إليها في أي وقت من قائمة مفضلتك</span>
              </li>
              <li>
                <span className={styles.checkIcon}>✓</span>
                <span>تابع أفضل العروض بسهولة</span>
              </li>
            </ul>

            {error && <p className={styles.error}>{error}</p>}

            <button
              className={styles.addBtn}
              onClick={handleAddFavorite}
              disabled={loading}
            >
              {loading ? (
                <span className={styles.spinner} />
              ) : (
                <>♥ إضافة للمفضلة</>
              )}
            </button>

            <button className={styles.cancelBtn} onClick={onClose}>
              إلغاء
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
