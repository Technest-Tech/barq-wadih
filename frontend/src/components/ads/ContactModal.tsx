'use client';

import React, { useState } from 'react';
import { Send } from 'lucide-react';
import styles from './ContactModal.module.css';

interface ContactModalProps {
  isOpen: boolean;
  onClose: () => void;
  phone: string;
  sellerName: string;
  onSendChat: (text: string) => Promise<void>;
  chatLoading?: boolean;
  initialDraft?: string;
}

const DEFAULT_DRAFT = 'السلام عليكم، هل السلعة متاحة؟';

export default function ContactModal({
  isOpen,
  onClose,
  phone,
  sellerName,
  onSendChat,
  chatLoading,
  initialDraft,
}: ContactModalProps) {
  const [text, setText] = useState(initialDraft ?? DEFAULT_DRAFT);
  const [error, setError] = useState<string | null>(null);

  // Reset draft each time the modal opens
  React.useEffect(() => {
    if (isOpen) {
      setText(initialDraft ?? DEFAULT_DRAFT);
      setError(null);
    }
  }, [isOpen, initialDraft]);

  if (!isOpen) return null;

  const trimmed   = text.trim();
  const canSubmit = trimmed.length > 0 && !chatLoading;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setError(null);
    try {
      await onSendChat(trimmed);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'تعذّر إرسال الرسالة';
      setError(msg);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      handleSubmit();
    }
  };

  return (
    <div className={styles.overlay} onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className={styles.modal} role="dialog" aria-modal="true">
        <button className={styles.closeBtn} onClick={onClose} aria-label="إغلاق">✕</button>

        <div className={styles.header}>
          <div className={styles.headerIcon}>
            <svg viewBox="0 0 24 24" fill="currentColor" width="26" height="26">
              <path d="M6.62 10.79a15.091 15.091 0 006.59 6.59l2.2-2.2a1 1 0 011.11-.27c1.12.37 2.33.57 3.58.57a1 1 0 011 1V20a1 1 0 01-1 1A19.93 19.93 0 012 2a1 1 0 011-1h3.5a1 1 0 011 1c0 1.25.2 2.46.57 3.58a1 1 0 01-.27 1.11l-2.2 2.2z"/>
            </svg>
          </div>
          <div>
            <h2 className={styles.title}>تواصل مع العارض</h2>
            <p className={styles.subtitle}>{sellerName}</p>
          </div>
        </div>

        <div className={styles.divider} />

        <div className={styles.options}>
          {/* Phone call — direct dialer */}
          {phone && (
            <a
              href={`tel:${phone}`}
              className={styles.phoneOption}
              onClick={onClose}
            >
              <div className={styles.optionIcon}>
                <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22">
                  <path d="M6.62 10.79a15.091 15.091 0 006.59 6.59l2.2-2.2a1 1 0 011.11-.27c1.12.37 2.33.57 3.58.57a1 1 0 011 1V20a1 1 0 01-1 1A19.93 19.93 0 012 2a1 1 0 011-1h3.5a1 1 0 011 1c0 1.25.2 2.46.57 3.58a1 1 0 01-.27 1.11l-2.2 2.2z"/>
                </svg>
              </div>
              <div className={styles.optionBody}>
                <span className={styles.optionLabel}>اتصال مباشر</span>
                <span className={styles.optionValue} dir="ltr">{phone}</span>
              </div>
              <svg className={styles.optionArrow} viewBox="0 0 24 24" fill="currentColor" width="16" height="16">
                <path d="M15.41 16.59L10.83 12l4.58-4.59L14 6l-6 6 6 6z"/>
              </svg>
            </a>
          )}

          {/* Chat composer card */}
          <div className={styles.composerCard}>
            <div className={styles.composerHead}>
              <div className={styles.optionIconChat}>
                <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
                  <path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/>
                </svg>
              </div>
              <div className={styles.composerHeadText}>
                <span className={styles.optionLabel}>مراسلة عبر برق واضح</span>
                <span className={styles.optionDesc}>تواصل آمن داخل المنصة</span>
              </div>
            </div>

            <textarea
              className={styles.composerTextarea}
              placeholder="اكتب رسالتك للبائع…"
              rows={3}
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={handleKeyDown}
              disabled={chatLoading}
              autoFocus
            />

            {error && <p className={styles.composerError}>{error}</p>}

            <button
              className={styles.composerSendBtn}
              onClick={handleSubmit}
              disabled={!canSubmit}
            >
              {chatLoading ? (
                <span className={styles.spinner} />
              ) : (
                <>
                  <Send size={16} />
                  <span>إرسال</span>
                </>
              )}
            </button>
          </div>
        </div>

        <p className={styles.warning}>
          ⚠️ لا تُرسل أموالاً مسبقاً ولا تشارك بياناتك البنكية قبل استلام البضاعة.
        </p>
      </div>
    </div>
  );
}
