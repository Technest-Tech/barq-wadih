'use client';

import { useEffect, useRef } from 'react';
import pm from '@/styles/premium.module.css';
import styles from '../../post-ad.module.css';
import { fetchCategoryFields, type CategoryField, type CategoryFieldOption } from '@/lib/api/ads';
import { isValidSaudiPhone, usePostAdWizard } from '@/store/postAdWizard.store';
import { WizardFooter } from '../WizardFooter';

type PriceOption = 'fixed' | 'negotiable' | 'call';

export function DetailsStep() {
  const category = usePostAdWizard((s) => s.category);
  const d = usePostAdWizard((s) => s.details);
  const patch = usePostAdWizard((s) => s.patchDetails);
  const categoryFields = usePostAdWizard((s) => s.categoryFields);
  const setCategoryFields = usePostAdWizard((s) => s.setCategoryFields);

  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const autoResize = (el: HTMLTextAreaElement) => {
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  };

  // Auto-size on mount in case store already has content
  useEffect(() => {
    if (textareaRef.current) autoResize(textareaRef.current);
  }, []);

  // Load the selected category's dynamic fields (e.g. the cars fields).
  useEffect(() => {
    if (!category) {
      setCategoryFields([]);
      return;
    }
    fetchCategoryFields(category.id)
      .then(setCategoryFields)
      .catch(() => setCategoryFields([]));
  }, [category, setCategoryFields]);

  // Derive the selected price option from the boolean flags.
  const priceOption: PriceOption = d.priceHidden ? 'call' : d.isNegotiable ? 'negotiable' : 'fixed';
  const selectPrice = (opt: PriceOption) => {
    if (opt === 'fixed') patch({ isFree: false, isNegotiable: false, priceHidden: false });
    else if (opt === 'negotiable') patch({ isFree: false, isNegotiable: true, priceHidden: false });
    else patch({ isFree: false, isNegotiable: false, priceHidden: true, price: '' });
  };

  const normalizeOption = (opt: CategoryFieldOption): { value: string; label: string } => {
    if (typeof opt === 'string') return { value: opt, label: opt };
    return {
      value: String(opt.value),
      label: String(opt.label_ar ?? opt.label ?? opt.label_en ?? opt.value),
    };
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
            maxLength={5000}
            placeholder="اكتب وصفاً دقيقاً للإعلان... (10 أحرف على الأقل)"
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

        {/* Dynamic category fields (e.g. cars: النوع/الموديل/الممشى/اللون) */}
        {categoryFields.length > 0 && (
          <>
            <div className={pm.pmGridFull}>
              <h3 className={pm.pmSectionTitle}>
                <span className={pm.pmSectionTitleIcon}>📋</span>
                المواصفات
              </h3>
            </div>
            {categoryFields.map((f: CategoryField) => {
              const val = d.fields[f.field_key] ?? '';
              const missing = f.is_required && val.trim().length === 0;
              const setVal = (v: string) => patch({ fields: { ...d.fields, [f.field_key]: v } });
              return (
                <div
                  key={f.id}
                  className={`${pm.pmField} ${f.field_type === 'text' ? pm.pmGridFull : ''}`}
                >
                  <label className={`${pm.pmLabel} ${f.is_required ? pm.pmLabelReq : ''}`}>
                    {f.label_ar}
                  </label>
                  {(f.field_type === 'select' || f.field_type === 'multi_select') &&
                  Array.isArray(f.options) ? (
                    <select
                      className={pm.pmInput}
                      value={val}
                      onChange={(e) => setVal(e.target.value)}
                    >
                      <option value="">اختر...</option>
                      {f.options.map((o) => {
                        const opt = normalizeOption(o);
                        return (
                          <option key={opt.value} value={opt.value}>
                            {opt.label}
                          </option>
                        );
                      })}
                    </select>
                  ) : (
                    <input
                      className={pm.pmInput}
                      type={
                        f.field_type === 'number' || f.field_type === 'year' ? 'number' : 'text'
                      }
                      placeholder={f.placeholder_ar ?? ''}
                      value={val}
                      onChange={(e) => setVal(e.target.value)}
                    />
                  )}
                  {missing && (
                    <span className={pm.pmHelp} style={{ color: 'var(--color-error)' }}>
                      هذا الحقل مطلوب
                    </span>
                  )}
                </div>
              );
            })}
          </>
        )}

        {/* Price — 3 options mirroring the mobile app */}
        <div className={pm.pmGridFull}>
          <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>السعر</label>
          <div style={{ display: 'flex', gap: 8 }}>
            {(
              [
                { key: 'fixed', label: '💵 أدخل السعر' },
                { key: 'negotiable', label: '🤝 على السوم' },
                { key: 'call', label: '📞 عند الاتصال' },
              ] as { key: PriceOption; label: string }[]
            ).map((o) => {
              const active = priceOption === o.key;
              return (
                <button
                  key={o.key}
                  type="button"
                  onClick={() => selectPrice(o.key)}
                  style={{
                    flex: 1,
                    padding: '10px 0',
                    borderRadius: 10,
                    border: `2px solid ${active ? '#6366f1' : '#334155'}`,
                    background: active ? 'rgba(99,102,241,0.18)' : 'transparent',
                    color: active ? '#a5b4fc' : '#94a3b8',
                    fontWeight: 700,
                    fontSize: '.85rem',
                    cursor: 'pointer',
                    transition: 'all .15s',
                  }}
                >
                  {o.label}
                </button>
              );
            })}
          </div>

          {priceOption !== 'call' && (
            <div className={pm.pmInputAffix} style={{ marginTop: 8 }}>
              <input
                className={pm.pmInput}
                type="number"
                inputMode="numeric"
                min={1}
                placeholder={priceOption === 'negotiable' ? 'السعر المطلوب' : 'مثال: 45000'}
                value={d.price}
                onChange={(e) => patch({ price: e.target.value })}
              />
              <span className={pm.pmAffix}>ر.س</span>
            </div>
          )}
          <span className={pm.pmHelp}>
            {priceOption === 'call'
              ? 'لن يظهر سعر — يتواصل المشتري معك للسعر.'
              : priceOption === 'negotiable'
                ? 'يظهر السعر مع وسم «على السوم» للمشترين.'
                : 'سيظهر السعر للمشترين.'}
          </span>
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

      <MissingFieldsHint />
      <WizardFooter />
    </div>
  );
}

function MissingFieldsHint() {
  const d = usePostAdWizard((s) => s.details);
  const categoryFields = usePostAdWizard((s) => s.categoryFields);

  const missing: string[] = [];
  if (d.title.trim().length < 3) missing.push('عنوان الإعلان (3 أحرف على الأقل)');
  if (d.description.trim().length < 10) missing.push('الوصف (10 أحرف على الأقل)');
  if (d.showPhonePublicly && !isValidSaudiPhone(d.phone)) missing.push('رقم جوال سعودي صحيح');
  if (!d.priceHidden && d.price.trim().length === 0) missing.push('السعر (أو اختر «عند الاتصال»)');
  for (const f of categoryFields) {
    if (f.is_required && (d.fields[f.field_key] ?? '').trim().length === 0) {
      missing.push(f.label_ar);
    }
  }

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
