'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchAdminUsers, type AdminUser } from '@/lib/api/admin';
import { sendMessageNow, type CampaignCreateData } from '@/lib/api/admin-notifications';
import styles from './MessageComposer.module.css';

export type TargetType = 'all' | 'specific_users';

export interface LockedRecipient {
  id: number;
  name: string;
  phone?: string | null;
}

interface Props {
  open: boolean;
  onClose: () => void;
  onSent: (message: string) => void;
  onError: (message: string) => void;
  /**
   * Pre-selected recipient. Passing one locks the composer to a direct
   * message and hides the audience picker — used by the "send message"
   * button on a single user's page.
   */
  lockedRecipient?: LockedRecipient;
}

const MAX_TITLE = 255;
const MAX_BODY = 1000;

export default function MessageComposer({
  open,
  onClose,
  onSent,
  onError,
  lockedRecipient,
}: Props) {
  const direct = Boolean(lockedRecipient);

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [target, setTarget] = useState<TargetType>(direct ? 'specific_users' : 'all');
  const [picked, setPicked] = useState<LockedRecipient[]>([]);
  const [scheduledAt, setScheduledAt] = useState('');
  const [sending, setSending] = useState(false);

  // ── User search ──────────────────────────────────────────────────────────
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<AdminUser[]>([]);
  const [searching, setSearching] = useState(false);
  // Sequence guard: a slow early request must not overwrite a later one.
  const searchSeq = useRef(0);

  const reset = useCallback(() => {
    setTitle('');
    setBody('');
    setTarget(direct ? 'specific_users' : 'all');
    setPicked(lockedRecipient ? [lockedRecipient] : []);
    setScheduledAt('');
    setQuery('');
    setResults([]);
  }, [direct, lockedRecipient]);

  useEffect(() => {
    if (open) reset();
  }, [open, reset]);

  useEffect(() => {
    if (!open || direct || target !== 'specific_users') return;

    const term = query.trim();
    if (term.length < 2) {
      setResults([]);
      return;
    }

    const seq = ++searchSeq.current;
    setSearching(true);
    const timer = setTimeout(async () => {
      try {
        const res = await fetchAdminUsers({ q: term, per_page: 8 });
        if (seq === searchSeq.current) setResults(res.data);
      } catch {
        if (seq === searchSeq.current) setResults([]);
      } finally {
        if (seq === searchSeq.current) setSearching(false);
      }
    }, 350);

    return () => clearTimeout(timer);
  }, [query, open, direct, target]);

  if (!open) return null;

  const togglePick = (u: AdminUser) => {
    setPicked((prev) =>
      prev.some((p) => p.id === u.id)
        ? prev.filter((p) => p.id !== u.id)
        : [...prev, { id: u.id, name: u.name, phone: u.phone }]
    );
  };

  const removePick = (id: number) => setPicked((prev) => prev.filter((p) => p.id !== id));

  const canSend =
    title.trim().length > 0 &&
    body.trim().length > 0 &&
    (target === 'all' || picked.length > 0) &&
    !sending;

  const handleSend = async () => {
    if (!canSend) return;
    setSending(true);
    try {
      const payload: CampaignCreateData = {
        title_ar: title.trim(),
        body_ar: body.trim(),
        target_type: target,
      };
      if (target === 'specific_users') payload.target_user_ids = picked.map((p) => p.id);
      // datetime-local yields a local wall-clock string; pass it through so the
      // API reads it in the app's timezone instead of shifting it.
      if (scheduledAt) payload.scheduled_at = scheduledAt;

      const res = await sendMessageNow(payload);

      onSent(
        scheduledAt
          ? `تمت جدولة الرسالة لـ ${res.recipients_count} مستخدم`
          : `جارٍ الإرسال إلى ${res.recipients_count} مستخدم`
      );
      onClose();
    } catch (e) {
      onError(e instanceof Error ? e.message : 'تعذّر إرسال الرسالة');
    } finally {
      setSending(false);
    }
  };

  return (
    <div className={styles.overlay} onClick={() => !sending && onClose()}>
      <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
        <div className={styles.header}>
          <h3 className={styles.title}>
            {direct ? `✉️ رسالة إلى ${lockedRecipient?.name}` : '📣 رسالة جديدة'}
          </h3>
          <button className={styles.close} onClick={onClose} disabled={sending}>
            ✕
          </button>
        </div>

        <div className={styles.body}>
          {/* ── Audience ── */}
          {!direct && (
            <div className={styles.field}>
              <label className={styles.label}>المستلمون</label>
              <div className={styles.segmented}>
                <button
                  type="button"
                  className={`${styles.segment} ${target === 'all' ? styles.segmentActive : ''}`}
                  onClick={() => setTarget('all')}
                >
                  كل المستخدمين
                </button>
                <button
                  type="button"
                  className={`${styles.segment} ${target === 'specific_users' ? styles.segmentActive : ''}`}
                  onClick={() => setTarget('specific_users')}
                >
                  مستخدمون محددون
                </button>
              </div>
              {target === 'all' && (
                <p className={styles.hint}>
                  ستصل الرسالة إلى كل حساب نشط كإشعار داخل التطبيق وإشعار على الجوال.
                </p>
              )}
            </div>
          )}

          {/* ── User picker ── */}
          {!direct && target === 'specific_users' && (
            <div className={styles.field}>
              <label className={styles.label}>بحث عن مستخدم</label>
              <input
                className={styles.input}
                placeholder="الاسم أو رقم الجوال أو البريد..."
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />

              {query.trim().length >= 2 && (
                <div className={styles.results}>
                  {searching ? (
                    <div className={styles.resultEmpty}>جارٍ البحث...</div>
                  ) : results.length === 0 ? (
                    <div className={styles.resultEmpty}>لا توجد نتائج</div>
                  ) : (
                    results.map((u) => {
                      const isPicked = picked.some((p) => p.id === u.id);
                      return (
                        <button
                          key={u.id}
                          type="button"
                          className={`${styles.result} ${isPicked ? styles.resultPicked : ''}`}
                          onClick={() => togglePick(u)}
                        >
                          <span className={styles.resultAvatar}>{u.name?.[0] || '?'}</span>
                          <span className={styles.resultInfo}>
                            <span className={styles.resultName}>{u.name}</span>
                            <span className={styles.resultMeta} dir="ltr">
                              {u.phone || u.email || `#${u.id}`}
                            </span>
                          </span>
                          <span className={styles.resultTick}>{isPicked ? '✓' : '+'}</span>
                        </button>
                      );
                    })
                  )}
                </div>
              )}

              {picked.length > 0 && (
                <div className={styles.chips}>
                  {picked.map((p) => (
                    <span key={p.id} className={styles.chip}>
                      {p.name}
                      <button type="button" onClick={() => removePick(p.id)} aria-label="إزالة">
                        ✕
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ── Message ── */}
          <div className={styles.field}>
            <label className={styles.label}>العنوان</label>
            <input
              className={styles.input}
              maxLength={MAX_TITLE}
              placeholder="مثال: تحديث في سياسة العمولة"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label}>
              نص الرسالة
              <span className={styles.counter}>
                {body.length}/{MAX_BODY}
              </span>
            </label>
            <textarea
              className={styles.textarea}
              maxLength={MAX_BODY}
              rows={5}
              placeholder="اكتب نص الرسالة كما ستظهر للمستخدم..."
              value={body}
              onChange={(e) => setBody(e.target.value)}
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label}>
              جدولة الإرسال <span className={styles.optional}>(اختياري)</span>
            </label>
            <input
              type="datetime-local"
              className={styles.input}
              value={scheduledAt}
              onChange={(e) => setScheduledAt(e.target.value)}
            />
            <p className={styles.hint}>اتركه فارغاً للإرسال فوراً.</p>
          </div>

          {/* ── Preview ── */}
          <div className={styles.preview}>
            <span className={styles.previewLabel}>معاينة الإشعار</span>
            <div className={styles.previewCard}>
              <span className={styles.previewIcon}>🔔</span>
              <div className={styles.previewText}>
                <div className={styles.previewTitle}>{title || 'عنوان الرسالة'}</div>
                <div className={styles.previewBody}>{body || 'نص الرسالة سيظهر هنا'}</div>
              </div>
            </div>
          </div>
        </div>

        <div className={styles.footer}>
          <button className={styles.cancelBtn} onClick={onClose} disabled={sending}>
            إلغاء
          </button>
          <button className={styles.sendBtn} onClick={handleSend} disabled={!canSend}>
            {sending ? 'جارٍ الإرسال...' : scheduledAt ? 'جدولة الرسالة' : 'إرسال الآن'}
          </button>
        </div>
      </div>
    </div>
  );
}
