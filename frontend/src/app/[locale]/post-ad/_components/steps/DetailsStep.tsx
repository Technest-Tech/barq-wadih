'use client';

import { useEffect, useRef } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { isValidSaudiPhone, usePostAdWizard } from '@/store/postAdWizard.store';
import { PriceField } from '../shared/PriceField';
import { WizardFooter } from '../WizardFooter';

export function DetailsStep() {
  const category = usePostAdWizard((s) => s.category);
  const d = usePostAdWizard((s) => s.details);
  const patch = usePostAdWizard((s) => s.patchDetails);

  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const autoResize = (el: HTMLTextAreaElement) => {
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  };

  // Auto-size on mount in case store already has content
  useEffect(() => {
    if (textareaRef.current) autoResize(textareaRef.current);
  }, []);

  return (
    <div>
      <header className={styles.stepHeader}>
        <span className={styles.stepIcon}>📝</span>
        <div>
          <div className={styles.stepTitle}>تفاصيل الإعلان</div>
          <div className={styles.stepSub}>{category?.name_ar ?? ''}</div>
        </div>
      </header>

      <div className={pm.pmGrid}>
        <div className={`${pm.pmField} ${pm.pmGridFull}`}>
          <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>عنوان الإعلان</label>
          <input
            className={pm.pmInput}
            placeholder="مثال: عنوان واضح ومختصر يصف الإعلان"
            maxLength={100}
            value={d.title}
            onChange={(e) => patch({ title: e.target.value })}
          />
          <span
            className={pm.pmHelp}
            style={
              d.title.trim().length > 0 && d.title.trim().length < 3
                ? { color: 'var(--color-error)' }
                : undefined
            }
          >
            {d.title.length} / 100 — الحد الأدنى 3 أحرف
          </span>
        </div>

        <div className={`${pm.pmField} ${pm.pmGridFull}`}>
          <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>الوصف</label>
          <textarea
            ref={textareaRef}
            className={`${pm.pmInput} ${pm.pmTextarea}`}
            rows={1}
            placeholder="اكتب وصفاً دقيقاً للإعلان..."
            value={d.description}
            onChange={(e) => {
              patch({ description: e.target.value });
              autoResize(e.target);
            }}
          />
          <span
            className={pm.pmHelp}
            style={
              d.description.trim().length > 0 && d.description.trim().length < 10
                ? { color: 'var(--color-error)' }
                : undefined
            }
          >
            {d.description.length} / 5000 — الحد الأدنى 10 أحرف
          </span>
        </div>

        <div className={pm.pmGridFull}>
          <PriceField />
        </div>

        <div className={pm.pmGridFull}>
          <button
            type="button"
            className={`${pm.pmToggleCard} ${d.showPhonePublicly ? pm.pmToggleOn : ''}`}
            onClick={() => patch({ showPhonePublicly: !d.showPhonePublicly })}
          >
            <div className={pm.pmToggleSwitch} />
            <div className={pm.pmToggleLabel}>
              <div className={pm.pmToggleTitle}>إظهار رقم الجوال للعموم</div>
              <div className={pm.pmToggleDesc}>
                عند الإيقاف يتواصل معك المشترون عبر المحادثات فقط
              </div>
            </div>
          </button>
        </div>

        {d.showPhonePublicly && (
          <div className={pm.pmField}>
            <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>رقم الجوال</label>
            <input
              className={pm.pmInput}
              placeholder="05xxxxxxxx"
              inputMode="numeric"
              maxLength={10}
              value={d.phone}
              onChange={(e) => patch({ phone: e.target.value.replace(/\D/g, '').slice(0, 10) })}
            />
            {d.phone.trim().length > 0 && !isValidSaudiPhone(d.phone) && (
              <span className={pm.pmHelp} style={{ color: 'var(--color-error)' }}>
                يرجى إدخال رقم سعودي صحيح (مثال: 0512345678)
              </span>
            )}
          </div>
        )}
      </div>

      <MissingFieldsHint details={d} />
      <WizardFooter />
    </div>
  );
}

function MissingFieldsHint({
  details: d,
}: {
  details: ReturnType<typeof usePostAdWizard.getState>['details'];
}) {
  const missing: string[] = [];
  if (d.title.trim().length < 3) missing.push('عنوان الإعلان (3 أحرف على الأقل)');
  if (d.description.trim().length < 10) missing.push('الوصف (10 أحرف على الأقل)');
  if (d.showPhonePublicly && !isValidSaudiPhone(d.phone)) missing.push('رقم جوال سعودي صحيح');
  if (!d.isFree && !d.priceHidden && d.price.trim().length === 0)
    missing.push('السعر (أو اختر لا تعرض السعر)');

  if (missing.length === 0) return null;
  return (
    <div
      style={{
        marginTop: 12,
        padding: '10px 12px',
        borderRadius: 10,
        background: 'rgba(234, 88, 12, 0.06)',
        border: '1px solid rgba(234, 88, 12, 0.25)',
        color: 'var(--color-warning)',
        fontSize: 12.5,
        lineHeight: 1.6,
      }}
    >
      ⚠ لإكمال هذه الخطوة:
      <ul style={{ margin: '4px 18px 0', padding: 0 }}>
        {missing.map((m) => (
          <li key={m}>{m}</li>
        ))}
      </ul>
    </div>
  );
}
