'use client';
import { useEffect, useState, useCallback, useMemo } from 'react';
import {
  fetchAdminCategories,
  createCategory,
  updateCategory,
  toggleCategory,
  fetchCategoryFields,
  createCategoryField,
  updateCategoryField,
  deleteCategoryField,
  type AdminCategory,
  type AdminCategoryField,
} from '@/lib/api/admin';
import s from '../admin-shared.module.css';
import cs from './categories.module.css';

// ── Constants ─────────────────────────────────────────────────────────────────

const FIELD_TYPES = [
  { value: 'text', label: 'نص' },
  { value: 'number', label: 'رقم' },
  { value: 'select', label: 'قائمة' },
  { value: 'checkbox', label: 'خانة اختيار' },
  { value: 'textarea', label: 'نص طويل' },
  { value: 'date', label: 'تاريخ' },
];

const CAT_COLORS = [
  '#6366f1',
  '#0ea5e9',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#ec4899',
  '#14b8a6',
  '#f97316',
  '#06b6d4',
  '#84cc16',
  '#a855f7',
  '#64748b',
  '#78716c',
  '#d97706',
  '#059669',
  '#dc2626',
  '#7c3aed',
  '#0284c7',
  '#374151',
];

// ── Form types ────────────────────────────────────────────────────────────────

interface CategoryForm {
  name_ar: string;
  name_en: string;
  icon: string;
  image: string;
  parent_id: number | null;
  description_ar: string;
  description_en: string;
  commission_rate: string;
  publish_fee_individual: string;
  publish_fee_dealer: string;
  fee_deductible_from_commission: boolean;
  deferred_commission_individual: string;
  deferred_commission_dealer: string;
  commission_trigger: 'after_sale' | 'after_90_days';
  is_free: boolean;
  is_active: boolean;
}
const emptyForm: CategoryForm = {
  name_ar: '',
  name_en: '',
  icon: '',
  image: '',
  parent_id: null,
  description_ar: '',
  description_en: '',
  commission_rate: '',
  publish_fee_individual: '',
  publish_fee_dealer: '',
  fee_deductible_from_commission: true,
  deferred_commission_individual: '',
  deferred_commission_dealer: '',
  commission_trigger: 'after_sale',
  is_free: false,
  is_active: true,
};

interface FieldForm {
  field_key: string;
  label_ar: string;
  label_en: string;
  field_type: string;
  options: string;
  is_required: boolean;
  is_filterable: boolean;
}
const emptyFieldForm: FieldForm = {
  field_key: '',
  label_ar: '',
  label_en: '',
  field_type: 'text',
  options: '',
  is_required: false,
  is_filterable: false,
};

// ── Component ─────────────────────────────────────────────────────────────────

export default function AdminCategoriesPage() {
  const [categories, setCategories] = useState<AdminCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [catModal, setCatModal] = useState<{ mode: 'create' | 'edit'; cat?: AdminCategory } | null>(
    null
  );
  const [form, setForm] = useState<CategoryForm>(emptyForm);
  const [busy, setBusy] = useState(false);
  const [fieldsModal, setFieldsModal] = useState<AdminCategory | null>(null);
  const [fields, setFields] = useState<AdminCategoryField[]>([]);
  const [fieldForm, setFieldForm] = useState<FieldForm>(emptyFieldForm);
  const [editFieldId, setEditFieldId] = useState<number | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'active' | 'inactive'>('all');

  // Subcategories management modal
  const [subsModalId, setSubsModalId] = useState<number | null>(null);
  const [subsSearch, setSubsSearch] = useState('');
  const [subsFilter, setSubsFilter] = useState<'all' | 'active' | 'inactive'>('all');

  const showToast = (msg: string, type: 'success' | 'error') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const d = await fetchAdminCategories();
      setCategories(d);
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Derive subsModal from categories so it stays fresh after reload
  const subsModal = useMemo(
    () => (subsModalId ? (categories.find((c) => c.id === subsModalId) ?? null) : null),
    [subsModalId, categories]
  );

  // ── Computed ──────────────────────────────────────────────────────────────

  const totalSubs = categories.reduce((acc, c) => acc + (c.children?.length ?? 0), 0);
  const totalActive = categories.filter((c) => c.is_active).length;
  const totalAds = categories.reduce(
    (acc, c) => acc + c.ads_count + (c.children?.reduce((a, ch) => a + ch.ads_count, 0) ?? 0),
    0
  );

  const q = search.toLowerCase();
  const filtered = categories.filter((cat) => {
    const matchesFilter =
      filter === 'all' || (filter === 'active' ? cat.is_active : !cat.is_active);
    if (!q) return matchesFilter;
    const nameMatch = cat.name_ar.includes(search) || cat.name_en.toLowerCase().includes(q);
    const childMatch = cat.children?.some(
      (c) => c.name_ar.includes(search) || c.name_en.toLowerCase().includes(q)
    );
    return matchesFilter && (nameMatch || childMatch);
  });

  const filteredSubs = useMemo(() => {
    if (!subsModal?.children) return [];
    const sq = subsSearch.toLowerCase();
    return subsModal.children.filter((sub) => {
      const matchesFilter =
        subsFilter === 'all' || (subsFilter === 'active' ? sub.is_active : !sub.is_active);
      if (!sq) return matchesFilter;
      return (
        matchesFilter &&
        (sub.name_ar.includes(subsSearch) || sub.name_en.toLowerCase().includes(sq))
      );
    });
  }, [subsModal, subsSearch, subsFilter]);

  // ── Handlers ──────────────────────────────────────────────────────────────

  const handleSave = async () => {
    if (!form.name_ar || !form.name_en) return;
    setBusy(true);
    try {
      let payload: FormData | Record<string, unknown>;
      if (imageFile) {
        const fd = new FormData();
        fd.append('name_ar', form.name_ar);
        fd.append('name_en', form.name_en);
        if (form.icon) fd.append('icon', form.icon);
        if (form.parent_id != null) fd.append('parent_id', String(form.parent_id));
        if (form.description_ar) fd.append('description_ar', form.description_ar);
        if (form.description_en) fd.append('description_en', form.description_en);
        if (form.commission_rate) fd.append('commission_rate', form.commission_rate);
        if (form.publish_fee_individual)
          fd.append('publish_fee_individual', form.publish_fee_individual);
        if (form.publish_fee_dealer) fd.append('publish_fee_dealer', form.publish_fee_dealer);
        fd.append(
          'fee_deductible_from_commission',
          form.fee_deductible_from_commission ? '1' : '0'
        );
        if (form.deferred_commission_individual)
          fd.append('deferred_commission_individual', form.deferred_commission_individual);
        if (form.deferred_commission_dealer)
          fd.append('deferred_commission_dealer', form.deferred_commission_dealer);
        fd.append('commission_trigger', form.commission_trigger);
        fd.append('is_free', form.is_free ? '1' : '0');
        fd.append('is_active', form.is_active ? '1' : '0');
        fd.append('image_file', imageFile);
        payload = fd;
      } else {
        payload = {
          ...form,
          commission_rate: form.commission_rate ? parseFloat(form.commission_rate) : null,
          publish_fee_individual: form.publish_fee_individual
            ? parseFloat(form.publish_fee_individual)
            : null,
          publish_fee_dealer: form.publish_fee_dealer ? parseFloat(form.publish_fee_dealer) : null,
        };
      }
      if (catModal?.mode === 'edit' && catModal.cat) {
        await updateCategory(catModal.cat.id, payload);
        showToast('تم تحديث التصنيف', 'success');
      } else {
        await createCategory(payload);
        showToast('تم إنشاء التصنيف', 'success');
      }
      setCatModal(null);
      setForm(emptyForm);
      setImageFile(null);
      setImagePreview(null);
      load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const handleToggle = async (cat: AdminCategory) => {
    try {
      await toggleCategory(cat.id);
      showToast(cat.is_active ? 'تم تعطيل التصنيف' : 'تم تفعيل التصنيف', 'success');
      load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    }
  };

  const openEdit = (cat: AdminCategory) => {
    setCatModal({ mode: 'edit', cat });
    setImageFile(null);
    setImagePreview(null);
    setForm({
      name_ar: cat.name_ar,
      name_en: cat.name_en,
      icon: cat.icon || '',
      image: cat.image || '',
      parent_id: cat.parent_id,
      description_ar: cat.description_ar || '',
      description_en: cat.description_en || '',
      commission_rate: cat.commission_rate || '',
      publish_fee_individual: cat.publish_fee_individual || '',
      publish_fee_dealer: cat.publish_fee_dealer || '',
      fee_deductible_from_commission: cat.fee_deductible_from_commission,
      deferred_commission_individual: cat.deferred_commission_individual || '',
      deferred_commission_dealer: cat.deferred_commission_dealer || '',
      commission_trigger: cat.commission_trigger ?? 'after_sale',
      is_free: cat.is_free,
      is_active: cat.is_active,
    });
  };

  const openAddSub = (parentId: number) => {
    setCatModal({ mode: 'create' });
    setForm({ ...emptyForm, parent_id: parentId });
  };

  const openSubsModal = (cat: AdminCategory) => {
    setSubsModalId(cat.id);
    setSubsSearch('');
    setSubsFilter('all');
  };

  // ── Category Fields ───────────────────────────────────────────────────────

  const openFields = async (cat: AdminCategory) => {
    setFieldsModal(cat);
    try {
      const f = await fetchCategoryFields(cat.id);
      setFields(f);
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    }
  };

  const handleFieldSave = async () => {
    if (!fieldsModal || !fieldForm.field_key || !fieldForm.label_ar) return;
    setBusy(true);
    const data = {
      ...fieldForm,
      options: fieldForm.options
        ? fieldForm.options
            .split(',')
            .map((o) => o.trim())
            .filter(Boolean)
        : null,
    };
    try {
      if (editFieldId) {
        await updateCategoryField(editFieldId, data);
        showToast('تم تحديث الحقل', 'success');
      } else {
        await createCategoryField(fieldsModal.id, data);
        showToast('تم إضافة الحقل', 'success');
      }
      setFieldForm(emptyFieldForm);
      setEditFieldId(null);
      const f = await fetchCategoryFields(fieldsModal.id);
      setFields(f);
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const handleFieldDelete = async (fieldId: number) => {
    try {
      await deleteCategoryField(fieldId);
      showToast('تم حذف الحقل', 'success');
      if (fieldsModal) {
        const f = await fetchCategoryFields(fieldsModal.id);
        setFields(f);
      }
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    }
  };

  const editField = (f: AdminCategoryField) => {
    setEditFieldId(f.id);
    setFieldForm({
      field_key: f.field_key,
      label_ar: f.label_ar,
      label_en: f.label_en,
      field_type: f.field_type,
      options: f.options?.join(', ') || '',
      is_required: f.is_required,
      is_filterable: f.is_filterable,
    });
  };

  // ── Render helpers ────────────────────────────────────────────────────────

  const isUrl = (v: string | null | undefined) => !!v && v.startsWith('http');

  const renderIcon = (icon: string | null | undefined, size: number, grayscale?: boolean) => {
    if (!icon) return <span style={{ fontSize: size }}>📂</span>;
    if (isUrl(icon))
      return (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={icon}
          alt=""
          width={size}
          height={size}
          style={{
            objectFit: 'contain',
            borderRadius: 4,
            filter: grayscale ? 'grayscale(1)' : 'none',
          }}
        />
      );
    return (
      <span style={{ fontSize: size, filter: grayscale ? 'grayscale(1)' : 'none' }}>{icon}</span>
    );
  };

  // ── Card renderer ─────────────────────────────────────────────────────────

  const renderCatCard = (cat: AdminCategory, idx: number) => {
    const color = CAT_COLORS[idx % CAT_COLORS.length];
    const subCount = cat.children?.length ?? 0;
    const activeSubCount = cat.children?.filter((c) => c.is_active).length ?? 0;
    const subAds = cat.children?.reduce((a, ch) => a + ch.ads_count, 0) ?? 0;
    const totalCatAds = cat.ads_count + subAds;
    const previewSubs = (cat.children ?? []).slice(0, 6);

    return (
      <div key={cat.id} className={`${cs.catCard} ${!cat.is_active ? cs.inactive : ''}`}>
        {/* Header */}
        <div className={cs.catHeader}>
          <div
            className={cs.catHeaderStrip}
            style={{ background: `linear-gradient(135deg, ${color}, transparent)` }}
          />
          <div className={cs.catIconWrap} style={{ boxShadow: `0 0 0 2px ${color}33` }}>
            {renderIcon(cat.image || cat.icon, 22, !cat.is_active)}
          </div>
          <div className={cs.catInfo}>
            <div className={cs.catName}>
              <span>{cat.name_ar}</span>
              {cat.is_free && (
                <span
                  className={cs.catBadge}
                  style={{
                    color: '#4ade80',
                    background: 'rgba(34,197,94,0.12)',
                    border: '1px solid rgba(34,197,94,0.2)',
                  }}
                >
                  مجاني
                </span>
              )}
              {!cat.is_active && (
                <span
                  className={cs.catBadge}
                  style={{
                    color: '#f87171',
                    background: 'rgba(239,68,68,0.12)',
                    border: '1px solid rgba(239,68,68,0.2)',
                  }}
                >
                  معطّل
                </span>
              )}
            </div>
            <div className={cs.catNameEn}>{cat.name_en}</div>
          </div>
          <div className={cs.catActions}>
            <button
              className={`${s.toggle} ${cat.is_active ? s.on : ''}`}
              onClick={() => handleToggle(cat)}
              title={cat.is_active ? 'تعطيل' : 'تفعيل'}
            />
          </div>
        </div>

        {/* Stats row */}
        <div className={cs.catStatsRow}>
          <div className={cs.catStat}>
            <div className={cs.catStatValue}>{subCount}</div>
            <div className={cs.catStatLabel}>فرعي</div>
          </div>
          <div className={cs.catStat}>
            <div className={cs.catStatValue} style={{ color: '#10b981' }}>
              {activeSubCount}
            </div>
            <div className={cs.catStatLabel}>نشط</div>
          </div>
          <div className={cs.catStat}>
            <div className={cs.catStatValue} style={{ color: '#0ea5e9' }}>
              {totalCatAds.toLocaleString('ar-SA')}
            </div>
            <div className={cs.catStatLabel}>إعلان</div>
          </div>
          {cat.commission_rate && (
            <div className={cs.catStat}>
              <div className={cs.catStatValue} style={{ color: '#fbbf24' }}>
                {cat.commission_rate}%
              </div>
              <div className={cs.catStatLabel}>عمولة</div>
            </div>
          )}
        </div>

        {/* Publish fee row */}
        {!!cat.publish_fee_individual && (
          <div className={cs.catFeeRow}>
            <div className={cs.catFeeBadge}>
              <span className={cs.catFeeIcon}>💳</span>
              <span className={cs.catFeeLabel}>رسوم النشر</span>
              <span className={cs.catFeeValue}>
                {Number(cat.publish_fee_individual ?? 0).toFixed(2)} ر.س
              </span>
            </div>
            {cat.fee_deductible_from_commission && (
              <div className={cs.catFeeNote} title="خصم من العمولة">
                ↩ يخصم من العمولة
              </div>
            )}
          </div>
        )}

        {/* Sub preview */}
        {subCount > 0 && (
          <div className={cs.catPreview}>
            {previewSubs.map((sub) => (
              <span key={sub.id} className={cs.previewChip} title={sub.name_ar}>
                <span className={cs.previewIcon}>{renderIcon(sub.image || sub.icon, 12)}</span>
                <span>{sub.name_ar}</span>
              </span>
            ))}
            {subCount > previewSubs.length && (
              <span className={cs.previewMore}>+{subCount - previewSubs.length}</span>
            )}
          </div>
        )}

        {/* Footer actions */}
        <div className={cs.catFooter}>
          <button
            className={`${cs.footerBtn} ${cs.footerBtnPrimary}`}
            onClick={() => openSubsModal(cat)}
          >
            🗂️ إدارة الفرعيات ({subCount})
          </button>
          <button className={cs.footerBtn} onClick={() => openFields(cat)} title="إدارة الحقول">
            📋 الحقول
          </button>
          <button className={cs.footerBtn} onClick={() => openEdit(cat)} title="تعديل التصنيف">
            ✏️
          </button>
        </div>
      </div>
    );
  };

  // ── Modals ────────────────────────────────────────────────────────────────

  const closeSubsModal = () => {
    setSubsModalId(null);
    setSubsSearch('');
    setSubsFilter('all');
  };

  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {/* ── Subcategories Management Modal ────────────────────────────────── */}
      {subsModal && (
        <div className={s.modalOverlay} onClick={closeSubsModal}>
          <div
            className={s.modal}
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: 760, padding: 0 }}
          >
            {/* Modal header */}
            <div className={cs.subsModalHeader}>
              <div className={cs.subsModalIcon}>
                {renderIcon(subsModal.image || subsModal.icon, 24)}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className={cs.subsModalTitle}>
                  الفرعيات تحت &quot;{subsModal.name_ar}&quot;
                </div>
                <div className={cs.subsModalSub}>
                  {subsModal.children?.length ?? 0} فرعي ·{' '}
                  {subsModal.children?.filter((c) => c.is_active).length ?? 0} نشط
                </div>
              </div>
              <button
                className={`${s.btn} ${s.primary} ${s.sm}`}
                onClick={() => openAddSub(subsModal.id)}
              >
                ➕ فرعي جديد
              </button>
              <button className={cs.subsModalClose} onClick={closeSubsModal} title="إغلاق">
                ✕
              </button>
            </div>

            {/* Search + filter */}
            <div className={cs.subsModalToolbar}>
              <input
                className={s.searchInput}
                style={{ flex: 1, minWidth: 180 }}
                placeholder="🔍 ابحث في الفرعيات..."
                value={subsSearch}
                onChange={(e) => setSubsSearch(e.target.value)}
              />
              <button
                className={`${s.chip} ${subsFilter === 'all' ? s.active : ''}`}
                onClick={() => setSubsFilter('all')}
              >
                الكل
              </button>
              <button
                className={`${s.chip} ${subsFilter === 'active' ? s.active : ''}`}
                onClick={() => setSubsFilter('active')}
              >
                نشط
              </button>
              <button
                className={`${s.chip} ${subsFilter === 'inactive' ? s.active : ''}`}
                onClick={() => setSubsFilter('inactive')}
              >
                معطّل
              </button>
            </div>

            {/* Sub list */}
            <div className={cs.subsList}>
              {filteredSubs.length === 0 ? (
                <div className={s.empty} style={{ padding: '40px 16px' }}>
                  <h3 style={{ fontSize: 15 }}>لا توجد فرعيات مطابقة</h3>
                </div>
              ) : (
                filteredSubs.map((sub) => (
                  <div
                    key={sub.id}
                    className={`${cs.subRow} ${!sub.is_active ? cs.subRowInactive : ''}`}
                  >
                    <div className={cs.subRowIcon}>
                      {renderIcon(sub.image || sub.icon, 18, !sub.is_active)}
                    </div>
                    <div className={cs.subRowInfo}>
                      <div className={cs.subRowName}>{sub.name_ar}</div>
                      <div className={cs.subRowMeta}>
                        {sub.name_en}
                        {sub.ads_count > 0 && <span> · {sub.ads_count} إعلان</span>}
                        {sub.fields_count > 0 && <span> · {sub.fields_count} حقل</span>}
                      </div>
                    </div>
                    <div className={cs.subRowActions}>
                      <button
                        className={`${s.toggle} ${sub.is_active ? s.on : ''}`}
                        onClick={() => handleToggle(sub)}
                        title={sub.is_active ? 'تعطيل' : 'تفعيل'}
                      />
                      <button
                        className={`${s.btn} ${s.sm}`}
                        onClick={() => openFields(sub)}
                        title="الحقول"
                      >
                        📋
                      </button>
                      <button
                        className={`${s.btn} ${s.sm}`}
                        onClick={() => openEdit(sub)}
                        title="تعديل"
                      >
                        ✏️
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {/* ── Category Create/Edit Modal ────────────────────────────────────── */}
      {catModal && (
        <div
          className={s.modalOverlay}
          onClick={() => {
            setCatModal(null);
            setForm(emptyForm);
            setImageFile(null);
            setImagePreview(null);
          }}
        >
          <div className={cs.pmModal} onClick={(e) => e.stopPropagation()}>
            {/* Header */}
            <div className={cs.pmHeader}>
              <div className={cs.pmHeaderIcon}>
                {form.icon ? renderIcon(form.icon, 26) : catModal.mode === 'edit' ? '✏️' : '➕'}
              </div>
              <div className={cs.pmHeaderText}>
                <div className={cs.pmHeaderTitle}>
                  {catModal.mode === 'edit'
                    ? 'تعديل التصنيف'
                    : form.parent_id
                      ? 'إضافة تصنيف فرعي'
                      : 'إضافة تصنيف رئيسي'}
                </div>
                <div className={cs.pmHeaderSub}>
                  {catModal.mode === 'edit' && catModal.cat ? (
                    <>تحديث بيانات &quot;{catModal.cat.name_ar}&quot;</>
                  ) : (
                    'املأ التفاصيل أدناه لإنشاء التصنيف'
                  )}
                </div>
              </div>
              <button
                className={cs.pmHeaderClose}
                onClick={() => {
                  setCatModal(null);
                  setForm(emptyForm);
                  setImageFile(null);
                  setImagePreview(null);
                }}
                title="إغلاق"
              >
                ✕
              </button>
            </div>

            {/* Body */}
            <div className={cs.pmBody}>
              {/* Section 1: Basic */}
              <div className={cs.pmSection}>
                <div className={cs.pmSectionTitle}>
                  <span className={cs.pmSectionTitleIcon}>📝</span>
                  <span>المعلومات الأساسية</span>
                </div>
                <div className={cs.pmSectionDesc}>اسم التصنيف، أيقونته، والتصنيف الأب إن وُجد</div>

                <div className={cs.pmGrid}>
                  <div className={cs.pmField}>
                    <label className={`${cs.pmLabel} ${cs.pmLabelReq}`}>الاسم (عربي)</label>
                    <input
                      className={cs.pmInput}
                      value={form.name_ar}
                      onChange={(e) => setForm({ ...form, name_ar: e.target.value })}
                      placeholder="مثال: سيارات"
                    />
                  </div>
                  <div className={cs.pmField}>
                    <label className={`${cs.pmLabel} ${cs.pmLabelReq}`}>الاسم (إنجليزي)</label>
                    <input
                      className={cs.pmInput}
                      value={form.name_en}
                      onChange={(e) => setForm({ ...form, name_en: e.target.value })}
                      placeholder="e.g. Cars"
                    />
                  </div>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>الأيقونة (emoji)</label>
                    <div className={cs.pmIconPicker}>
                      <div className={cs.pmIconPreview}>
                        {form.icon ? renderIcon(form.icon, 22) : '📂'}
                      </div>
                      <input
                        className={cs.pmInput}
                        value={form.icon}
                        onChange={(e) => setForm({ ...form, icon: e.target.value })}
                        placeholder="🚗"
                      />
                    </div>
                  </div>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>صورة التصنيف</label>
                    <div
                      style={{
                        border: '1.5px dashed #334155',
                        borderRadius: 8,
                        padding: '10px',
                        cursor: 'pointer',
                        textAlign: 'center',
                        background: '#0f172a',
                      }}
                      onClick={() => document.getElementById('cat-image-upload')?.click()}
                    >
                      <input
                        id="cat-image-upload"
                        type="file"
                        accept="image/jpg,image/jpeg,image/png,image/webp,image/svg+xml,.svg"
                        style={{ display: 'none' }}
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) {
                            setImageFile(file);
                            setImagePreview(URL.createObjectURL(file));
                          }
                        }}
                      />
                      {imagePreview ? (
                        <img
                          src={imagePreview}
                          alt="preview"
                          style={{ maxHeight: 80, borderRadius: 6, objectFit: 'contain' }}
                        />
                      ) : form.image ? (
                        <img
                          src={form.image}
                          alt="current"
                          style={{ maxHeight: 80, borderRadius: 6, objectFit: 'contain' }}
                        />
                      ) : (
                        <span style={{ color: '#64748b', fontSize: '.85rem' }}>
                          📁 اضغط لرفع صورة (JPG/PNG/WebP/SVG، حد 5MB)
                        </span>
                      )}
                    </div>
                    {(imagePreview || form.image) && (
                      <button
                        style={{
                          marginTop: 4,
                          fontSize: '.75rem',
                          color: '#ef4444',
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          padding: 0,
                        }}
                        onClick={() => {
                          setImageFile(null);
                          setImagePreview(null);
                          setForm((f) => ({ ...f, image: '' }));
                        }}
                      >
                        ✕ إزالة الصورة
                      </button>
                    )}
                  </div>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>التصنيف الأب</label>
                    <select
                      className={cs.pmInput}
                      value={form.parent_id || ''}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          parent_id: e.target.value ? Number(e.target.value) : null,
                        })
                      }
                    >
                      <option value="">بدون (تصنيف رئيسي)</option>
                      {categories.map((c) => (
                        <option key={c.id} value={c.id}>
                          {isUrl(c.icon) ? '' : (c.icon ?? '')} {c.name_ar}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              {/* Section 2: Pricing */}
              <div className={`${cs.pmSection} ${cs.pmSectionAccentGreen}`}>
                <div className={cs.pmSectionTitle}>
                  <span
                    className={cs.pmSectionTitleIcon}
                    style={{
                      background: 'rgba(16,185,129,0.15)',
                      borderColor: 'rgba(16,185,129,0.3)',
                    }}
                  >
                    💳
                  </span>
                  <span>رسوم النشر والعمولة</span>
                </div>
                <div className={cs.pmSectionDesc}>
                  الدفع المسبق إلزامي عبر Apple Pay / مدى. لا يُنشر الإعلان قبل نجاح الدفع.
                </div>

                <div className={cs.pmGrid}>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>👤 رسوم النشر</label>
                    <div className={cs.pmInputAffix}>
                      <input
                        className={cs.pmInput}
                        type="number"
                        step="0.01"
                        min="0"
                        value={form.publish_fee_individual}
                        onChange={(e) =>
                          setForm({ ...form, publish_fee_individual: e.target.value })
                        }
                        placeholder="3.00"
                      />
                      <span className={cs.pmAffix}>ر.س</span>
                    </div>
                    <div className={cs.pmHelp}>سيارات: 20 — أقسام أخرى: 3</div>
                  </div>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>📊 نسبة العمولة على البيع</label>
                    <div className={cs.pmInputAffix}>
                      <input
                        className={cs.pmInput}
                        type="number"
                        step="0.01"
                        value={form.commission_rate}
                        onChange={(e) => setForm({ ...form, commission_rate: e.target.value })}
                        placeholder="0.00"
                      />
                      <span className={cs.pmAffix}>%</span>
                    </div>
                    <div className={cs.pmHelp}>تُحتسب من قيمة الصفقة</div>
                  </div>
                </div>

                {/* Deferred commission (بالذمة) */}
                <div
                  style={{
                    marginTop: 12,
                    padding: '10px 12px',
                    background: 'rgba(99,102,241,0.07)',
                    borderRadius: 8,
                    border: '1px solid rgba(99,102,241,0.18)',
                  }}
                >
                  <div
                    style={{
                      fontSize: '.8rem',
                      fontWeight: 700,
                      color: '#a5b4fc',
                      marginBottom: 8,
                    }}
                  >
                    💰 العمولة المؤجلة (بالذمة)
                  </div>
                  <div className={cs.pmGrid}>
                    <div className={cs.pmField}>
                      <label className={cs.pmLabel}>💰 المبلغ المؤجل (بالذمة)</label>
                      <div className={cs.pmInputAffix}>
                        <input
                          className={cs.pmInput}
                          type="number"
                          step="0.01"
                          min="0"
                          value={form.deferred_commission_individual}
                          onChange={(e) =>
                            setForm({ ...form, deferred_commission_individual: e.target.value })
                          }
                          placeholder="0.00"
                        />
                        <span className={cs.pmAffix}>ر.س</span>
                      </div>
                    </div>
                  </div>
                  <div className={cs.pmField} style={{ marginTop: 8 }}>
                    <label className={cs.pmLabel}>⏰ موعد الاستحقاق</label>
                    <select
                      className={cs.pmInput}
                      value={form.commission_trigger}
                      onChange={(e) =>
                        setForm({
                          ...form,
                          commission_trigger: e.target.value as 'after_sale' | 'after_90_days',
                        })
                      }
                    >
                      <option value="after_sale">بعد إعلان البيع</option>
                      <option value="after_90_days">بعد 90 يوماً</option>
                    </select>
                  </div>
                </div>

                <div className={cs.pmToggleRow} style={{ marginTop: 12 }}>
                  <div
                    className={`${cs.pmToggleCard} ${form.fee_deductible_from_commission ? cs.pmToggleOn : ''}`}
                    onClick={() =>
                      setForm({
                        ...form,
                        fee_deductible_from_commission: !form.fee_deductible_from_commission,
                      })
                    }
                  >
                    <div className={cs.pmToggleSwitch} />
                    <div className={cs.pmToggleLabel}>
                      <div className={cs.pmToggleTitle}>↩ خصم من العمولة النهائية</div>
                      <div className={cs.pmToggleDesc}>تُخصم رسوم النشر من العمولة بعد البيع</div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Section 3: Settings */}
              <div className={cs.pmSection}>
                <div className={cs.pmSectionTitle}>
                  <span className={cs.pmSectionTitleIcon}>⚙️</span>
                  <span>الإعدادات</span>
                </div>
                <div className={cs.pmToggleRow}>
                  <div
                    className={`${cs.pmToggleCard} ${form.is_active ? cs.pmToggleOn : ''}`}
                    onClick={() => setForm({ ...form, is_active: !form.is_active })}
                  >
                    <div className={cs.pmToggleSwitch} />
                    <div className={cs.pmToggleLabel}>
                      <div className={cs.pmToggleTitle}>التصنيف مفعّل</div>
                      <div className={cs.pmToggleDesc}>يظهر للمستخدمين في التطبيق</div>
                    </div>
                  </div>
                  <div
                    className={`${cs.pmToggleCard} ${form.is_free ? cs.pmToggleOn : ''}`}
                    onClick={() => setForm({ ...form, is_free: !form.is_free })}
                  >
                    <div className={cs.pmToggleSwitch} />
                    <div className={cs.pmToggleLabel}>
                      <div className={cs.pmToggleTitle}>مجاني</div>
                      <div className={cs.pmToggleDesc}>بدون رسوم نشر للمستخدمين</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className={cs.pmFooter}>
              <button
                className={`${cs.pmBtn} ${cs.pmBtnGhost}`}
                onClick={() => {
                  setCatModal(null);
                  setForm(emptyForm);
                  setImageFile(null);
                  setImagePreview(null);
                }}
              >
                إلغاء
              </button>
              <button
                className={`${cs.pmBtn} ${cs.pmBtnPrimary}`}
                onClick={handleSave}
                disabled={busy || !form.name_ar || !form.name_en}
              >
                {busy
                  ? '⏳ جارٍ الحفظ...'
                  : catModal.mode === 'edit'
                    ? '💾 حفظ التغييرات'
                    : '✨ إنشاء التصنيف'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Fields Modal ──────────────────────────────────────────────────── */}
      {fieldsModal && (
        <div
          className={s.modalOverlay}
          onClick={() => {
            setFieldsModal(null);
            setFields([]);
            setFieldForm(emptyFieldForm);
            setEditFieldId(null);
          }}
        >
          <div className={cs.pmModal} onClick={(e) => e.stopPropagation()}>
            {/* Header */}
            <div className={cs.pmHeader}>
              <div className={cs.pmHeaderIcon}>📋</div>
              <div className={cs.pmHeaderText}>
                <div className={cs.pmHeaderTitle}>حقول التصنيف</div>
                <div className={cs.pmHeaderSub}>
                  {renderIcon(fieldsModal.image || fieldsModal.icon, 14)} {fieldsModal.name_ar} ·{' '}
                  {fields.length} حقل
                </div>
              </div>
              <button
                className={cs.pmHeaderClose}
                onClick={() => {
                  setFieldsModal(null);
                  setFields([]);
                  setFieldForm(emptyFieldForm);
                  setEditFieldId(null);
                }}
                title="إغلاق"
              >
                ✕
              </button>
            </div>

            {/* Body */}
            <div className={cs.pmBody}>
              {/* Existing fields */}
              <div className={cs.pmSection}>
                <div className={cs.pmSectionTitle}>
                  <span className={cs.pmSectionTitleIcon}>📃</span>
                  <span>الحقول الحالية</span>
                </div>

                {fields.length === 0 ? (
                  <div className={cs.pmEmpty}>
                    <div className={cs.pmEmptyIcon}>📭</div>
                    <div className={cs.pmEmptyText}>
                      لا توجد حقول مضافة بعد. ابدأ بإضافة حقل جديد أدناه.
                    </div>
                  </div>
                ) : (
                  <div>
                    {fields.map((f) => (
                      <div key={f.id} className={cs.pmFieldRow}>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              marginBottom: 4,
                              flexWrap: 'wrap',
                            }}
                          >
                            <span
                              style={{ fontSize: 14, fontWeight: 700, color: 'var(--admin-text)' }}
                            >
                              {f.label_ar}
                            </span>
                            <span className={cs.pmFieldType}>
                              {FIELD_TYPES.find((t) => t.value === f.field_type)?.label}
                            </span>
                            {f.is_required && (
                              <span
                                className={cs.pmFieldType}
                                style={{ background: 'rgba(239,68,68,0.15)', color: '#fca5a5' }}
                              >
                                مطلوب
                              </span>
                            )}
                            {f.is_filterable && (
                              <span
                                className={cs.pmFieldType}
                                style={{ background: 'rgba(34,197,94,0.15)', color: '#86efac' }}
                              >
                                فلتر
                              </span>
                            )}
                          </div>
                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: 6,
                              fontSize: 12,
                              color: 'var(--admin-text-muted)',
                            }}
                          >
                            <span className={cs.pmFieldKey}>{f.field_key}</span>
                            {f.label_en && <span>· {f.label_en}</span>}
                          </div>
                        </div>
                        <div style={{ display: 'flex', gap: 6 }}>
                          <button
                            className={`${s.btn} ${s.sm}`}
                            onClick={() => editField(f)}
                            title="تعديل"
                          >
                            ✏️
                          </button>
                          <button
                            className={`${s.btn} ${s.danger} ${s.sm}`}
                            onClick={() => handleFieldDelete(f.id)}
                            title="حذف"
                          >
                            🗑️
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Add / edit field */}
              <div className={`${cs.pmSection} ${cs.pmSectionAccent}`}>
                <div className={cs.pmSectionTitle}>
                  <span className={cs.pmSectionTitleIcon}>{editFieldId ? '✏️' : '➕'}</span>
                  <span>{editFieldId ? 'تعديل الحقل' : 'إضافة حقل جديد'}</span>
                </div>
                <div className={cs.pmSectionDesc}>
                  الحقول تظهر للمستخدم عند إضافة إعلان في هذا التصنيف
                </div>

                <div className={cs.pmGrid}>
                  <div className={cs.pmField}>
                    <label className={`${cs.pmLabel} ${cs.pmLabelReq}`}>المفتاح (key)</label>
                    <input
                      className={cs.pmInput}
                      value={fieldForm.field_key}
                      onChange={(e) => setFieldForm({ ...fieldForm, field_key: e.target.value })}
                      placeholder="year"
                    />
                    <div className={cs.pmHelp}>معرّف فني — أحرف إنجليزية فقط</div>
                  </div>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>نوع الحقل</label>
                    <select
                      className={cs.pmInput}
                      value={fieldForm.field_type}
                      onChange={(e) => setFieldForm({ ...fieldForm, field_type: e.target.value })}
                    >
                      {FIELD_TYPES.map((t) => (
                        <option key={t.value} value={t.value}>
                          {t.label}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className={cs.pmField}>
                    <label className={`${cs.pmLabel} ${cs.pmLabelReq}`}>التسمية (عربي)</label>
                    <input
                      className={cs.pmInput}
                      value={fieldForm.label_ar}
                      onChange={(e) => setFieldForm({ ...fieldForm, label_ar: e.target.value })}
                      placeholder="السنة"
                    />
                  </div>
                  <div className={cs.pmField}>
                    <label className={cs.pmLabel}>التسمية (إنجليزي)</label>
                    <input
                      className={cs.pmInput}
                      value={fieldForm.label_en}
                      onChange={(e) => setFieldForm({ ...fieldForm, label_en: e.target.value })}
                      placeholder="Year"
                    />
                  </div>
                </div>

                {(fieldForm.field_type === 'select' || fieldForm.field_type === 'checkbox') && (
                  <div className={cs.pmField} style={{ marginTop: 12 }}>
                    <label className={cs.pmLabel}>الخيارات</label>
                    <input
                      className={cs.pmInput}
                      value={fieldForm.options}
                      onChange={(e) => setFieldForm({ ...fieldForm, options: e.target.value })}
                      placeholder="جديد, مستعمل, ممتاز"
                    />
                    <div className={cs.pmHelp}>افصل الخيارات بفاصلة</div>
                  </div>
                )}

                <div className={cs.pmToggleRow} style={{ marginTop: 12 }}>
                  <div
                    className={`${cs.pmToggleCard} ${fieldForm.is_required ? cs.pmToggleOn : ''}`}
                    onClick={() =>
                      setFieldForm({ ...fieldForm, is_required: !fieldForm.is_required })
                    }
                  >
                    <div className={cs.pmToggleSwitch} />
                    <div className={cs.pmToggleLabel}>
                      <div className={cs.pmToggleTitle}>حقل مطلوب</div>
                      <div className={cs.pmToggleDesc}>لا يمكن نشر إعلان دونه</div>
                    </div>
                  </div>
                  <div
                    className={`${cs.pmToggleCard} ${fieldForm.is_filterable ? cs.pmToggleOn : ''}`}
                    onClick={() =>
                      setFieldForm({ ...fieldForm, is_filterable: !fieldForm.is_filterable })
                    }
                  >
                    <div className={cs.pmToggleSwitch} />
                    <div className={cs.pmToggleLabel}>
                      <div className={cs.pmToggleTitle}>قابل للفلترة</div>
                      <div className={cs.pmToggleDesc}>يظهر في خيارات البحث</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className={cs.pmFooter}>
              {editFieldId && (
                <button
                  className={`${cs.pmBtn} ${cs.pmBtnGhost}`}
                  onClick={() => {
                    setEditFieldId(null);
                    setFieldForm(emptyFieldForm);
                  }}
                >
                  إلغاء التعديل
                </button>
              )}
              <button
                className={`${cs.pmBtn} ${cs.pmBtnGhost}`}
                onClick={() => {
                  setFieldsModal(null);
                  setFields([]);
                  setFieldForm(emptyFieldForm);
                  setEditFieldId(null);
                }}
              >
                إغلاق
              </button>
              <button
                className={`${cs.pmBtn} ${cs.pmBtnPrimary}`}
                onClick={handleFieldSave}
                disabled={busy || !fieldForm.field_key || !fieldForm.label_ar}
              >
                {busy ? '⏳ جارٍ الحفظ...' : editFieldId ? '💾 تحديث الحقل' : '➕ إضافة الحقل'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Page Header ───────────────────────────────────────────────────── */}
      <div className={s.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <h1 className={s.pageTitle}>إدارة التصنيفات</h1>
          {!loading && (
            <span className={s.totalBadge}>
              {categories.length} رئيسي · {totalSubs} فرعي
            </span>
          )}
        </div>
        <button
          className={`${s.btn} ${s.primary}`}
          onClick={() => {
            setCatModal({ mode: 'create' });
            setForm(emptyForm);
          }}
        >
          ➕ تصنيف جديد
        </button>
      </div>

      {loading ? (
        <div className={s.loading}>
          <div className={s.spinner} />
        </div>
      ) : (
        <>
          {/* ── Stats ─────────────────────────────────────────────────────── */}
          <div className={cs.statsRow}>
            <div className={cs.statCard}>
              <div className={cs.statValue} style={{ color: '#6366f1' }}>
                {categories.length}
              </div>
              <div className={cs.statLabel}>تصنيف رئيسي</div>
            </div>
            <div className={cs.statCard}>
              <div className={cs.statValue} style={{ color: '#0ea5e9' }}>
                {totalSubs}
              </div>
              <div className={cs.statLabel}>تصنيف فرعي</div>
            </div>
            <div className={cs.statCard}>
              <div className={cs.statValue} style={{ color: '#10b981' }}>
                {totalActive}
              </div>
              <div className={cs.statLabel}>نشط</div>
            </div>
            <div className={cs.statCard}>
              <div className={cs.statValue} style={{ color: '#f59e0b' }}>
                {totalAds.toLocaleString('ar-SA')}
              </div>
              <div className={cs.statLabel}>إجمالي الإعلانات</div>
            </div>
          </div>

          {/* ── Search & Filter ────────────────────────────────────────────── */}
          <div className={cs.filterCard}>
            <input
              className={s.searchInput}
              style={{ flex: 1, minWidth: 200 }}
              placeholder="🔍 بحث في التصنيفات..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <button
              className={`${s.chip} ${filter === 'all' ? s.active : ''}`}
              onClick={() => setFilter('all')}
            >
              الكل ({categories.length})
            </button>
            <button
              className={`${s.chip} ${filter === 'active' ? s.active : ''}`}
              onClick={() => setFilter('active')}
            >
              نشط ({totalActive})
            </button>
            <button
              className={`${s.chip} ${filter === 'inactive' ? s.active : ''}`}
              onClick={() => setFilter('inactive')}
            >
              معطّل ({categories.length - totalActive})
            </button>
          </div>

          {/* ── Category Cards Grid ────────────────────────────────────────── */}
          {filtered.length === 0 ? (
            <div className={s.empty}>
              <h3>لا توجد تصنيفات مطابقة</h3>
              <p style={{ fontSize: 14, marginTop: 8 }}>جرّب تغيير البحث أو الفلتر</p>
            </div>
          ) : (
            <div className={cs.catGrid}>
              {filtered.map((cat, idx) =>
                renderCatCard(cat, categories.indexOf(cat) === -1 ? idx : categories.indexOf(cat))
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}
