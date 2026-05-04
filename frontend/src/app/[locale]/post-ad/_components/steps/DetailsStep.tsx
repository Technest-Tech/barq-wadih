'use client';

import { useEffect, useRef, useState } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { fetchCategoryFields, type CategoryField, type CategoryFieldOption } from '@/lib/api/ads';
import { isValidSaudiPhone, usePostAdWizard } from '@/store/postAdWizard.store';
import { PriceField } from '../shared/PriceField';
import { WizardFooter } from '../WizardFooter';

export function DetailsStep() {
  const category = usePostAdWizard(s => s.category);
  const d = usePostAdWizard(s => s.details);
  const patch = usePostAdWizard(s => s.patchDetails);

  const [fields, setFields] = useState<CategoryField[]>([]);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!category) return;
    fetchCategoryFields(category.id).then(setFields).catch(console.error);
  }, [category]);

  // Auto-size on mount in case store already has content
  useEffect(() => {
    if (textareaRef.current) autoResize(textareaRef.current);
  }, []);

  const normalizeOption = (opt: CategoryFieldOption): { value: string; label: string } => {
    if (typeof opt === 'string') return { value: opt, label: opt };
    return { value: String(opt.value), label: String(opt.label_ar ?? opt.label ?? opt.label_en ?? opt.value) };
  };

  const optionsOf = (f: CategoryField) =>
    Array.isArray(f.options) ? f.options.map(normalizeOption) : [];

  const autoResize = (el: HTMLTextAreaElement) => {
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  };

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
            placeholder="مثال: تويوتا لاندكروزر 2022 — فل كامل"
            maxLength={100}
            value={d.title}
            onChange={(e) => patch({ title: e.target.value })}
          />
          <span className={pm.pmHelp} style={d.title.trim().length > 0 && d.title.trim().length < 3 ? { color: 'var(--color-error)' } : undefined}>
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
          <span className={pm.pmHelp} style={d.description.trim().length > 0 && d.description.trim().length < 10 ? { color: 'var(--color-error)' } : undefined}>
            {d.description.length} / 5000 — الحد الأدنى 10 أحرف
          </span>
        </div>

        <div className={pm.pmGridFull}>
          <PriceField />
        </div>

        {fields.length > 0 && (
          <>
            <div className={pm.pmGridFull}>
              <h3 className={pm.pmSectionTitle}>
                <span className={pm.pmSectionTitleIcon}>📋</span>
                معلومات إضافية
              </h3>
            </div>
            {fields.map(f => (
              <div key={f.id} className={`${pm.pmField} ${f.field_type === 'text' ? pm.pmGridFull : ''}`}>
                <label className={`${pm.pmLabel} ${f.is_required ? pm.pmLabelReq : ''}`}>{f.label_ar}</label>
                {(f.field_type === 'select' || f.field_type === 'multi_select') && Array.isArray(f.options) ? (
                  <select
                    className={pm.pmInput}
                    value={d.fields[f.field_key] ?? ''}
                    onChange={(e) => patch({ fields: { ...d.fields, [f.field_key]: e.target.value } })}
                  >
                    <option value="">اختر...</option>
                    {optionsOf(f).map(opt => (
                      <option key={opt.value} value={opt.value}>{opt.label}</option>
                    ))}
                  </select>
                ) : f.field_type === 'boolean' ? (
                  <select
                    className={pm.pmInput}
                    value={d.fields[f.field_key] ?? ''}
                    onChange={(e) => patch({ fields: { ...d.fields, [f.field_key]: e.target.value } })}
                  >
                    <option value="">اختر...</option>
                    <option value="true">نعم</option>
                    <option value="false">لا</option>
                  </select>
                ) : (
                  <input
                    className={pm.pmInput}
                    type={f.field_type === 'number' || f.field_type === 'year' ? 'number' : 'text'}
                    placeholder={f.placeholder_ar ?? ''}
                    value={d.fields[f.field_key] ?? ''}
                    onChange={(e) => patch({ fields: { ...d.fields, [f.field_key]: e.target.value } })}
                  />
                )}
              </div>
            ))}
          </>
        )}

        <div className={pm.pmGridFull}>
          <button
            type="button"
            className={`${pm.pmToggleCard} ${d.showPhonePublicly ? pm.pmToggleOn : ''}`}
            onClick={() => patch({ showPhonePublicly: !d.showPhonePublicly })}
          >
            <div className={pm.pmToggleSwitch} />
            <div className={pm.pmToggleLabel}>
              <div className={pm.pmToggleTitle}>إظهار رقم الجوال للعموم</div>
              <div className={pm.pmToggleDesc}>عند الإيقاف يتواصل معك المشترون عبر المحادثات فقط</div>
            </div>
          </button>
        </div>

        {d.showPhonePublicly && (
          <div className={pm.pmField}>
            <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>رقم الجوال</label>
            <input
              className={pm.pmInput}
              placeholder="05xxxxxxxx"
              inputMode="tel"
              value={d.phone}
              onChange={(e) => patch({ phone: e.target.value })}
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

function MissingFieldsHint({ details: d }: { details: ReturnType<typeof usePostAdWizard.getState>['details'] }) {
  const missing: string[] = [];
  if (d.title.trim().length < 3)        missing.push('عنوان الإعلان (3 أحرف على الأقل)');
  if (d.description.trim().length < 10) missing.push('الوصف (10 أحرف على الأقل)');
  if (d.showPhonePublicly && !isValidSaudiPhone(d.phone)) missing.push('رقم جوال سعودي صحيح');
  if (!d.isFree && !d.priceHidden && d.price.trim().length === 0) missing.push('السعر (أو اختر لا تعرض السعر)');

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
        {missing.map(m => <li key={m}>{m}</li>)}
      </ul>
    </div>
  );
}
