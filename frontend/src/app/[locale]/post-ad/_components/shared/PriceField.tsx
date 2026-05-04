'use client';

import pm from '@/styles/premium.module.css';
import { usePostAdWizard } from '@/store/postAdWizard.store';

export function PriceField() {
  const d = usePostAdWizard(s => s.details);
  const patch = usePostAdWizard(s => s.patchDetails);

  const showPriceInput = !d.isFree && !d.priceHidden;

  const toggle = () => {
    if (showPriceInput) {
      patch({ priceHidden: true, isFree: false, isNegotiable: false, price: '' });
    } else {
      patch({ isFree: false, priceHidden: false });
    }
  };

  return (
    <div className={pm.pmField}>
      <label className={`${pm.pmLabel} ${pm.pmLabelReq}`}>السعر</label>

      <button
        type="button"
        className={`${pm.pmToggleCard} ${showPriceInput ? pm.pmToggleOn : ''}`}
        onClick={toggle}
      >
        <div className={pm.pmToggleSwitch} />
        <div className={pm.pmToggleLabel}>
          <div className={pm.pmToggleTitle}>إظهار السعر</div>
          <div className={pm.pmToggleDesc}>
            {showPriceInput ? 'سيظهر السعر للمشترين' : 'اتصل للسعر — لن يظهر سعر'}
          </div>
        </div>
      </button>

      {showPriceInput && (
        <div className={pm.pmInputAffix} style={{ marginTop: 8 }}>
          <input
            className={pm.pmInput}
            type="number"
            inputMode="numeric"
            min={0}
            placeholder="مثال: 45000"
            value={d.price}
            onChange={(e) => patch({ price: e.target.value })}
          />
          <span className={pm.pmAffix}>ر.س</span>
        </div>
      )}
    </div>
  );
}
