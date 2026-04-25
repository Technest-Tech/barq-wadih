'use client';
import { useEffect, useState, useCallback } from 'react';
import {
  fetchAdminCategories, createCategory, updateCategory, toggleCategory,
  fetchCategoryFields, createCategoryField, updateCategoryField, deleteCategoryField,
  type AdminCategory, type AdminCategoryField,
} from '@/lib/api/admin';
import s from '../admin-shared.module.css';

const FIELD_TYPES = [
  { value: 'text', label: 'نص' }, { value: 'number', label: 'رقم' },
  { value: 'select', label: 'قائمة' }, { value: 'checkbox', label: 'خانة اختيار' },
  { value: 'textarea', label: 'نص طويل' }, { value: 'date', label: 'تاريخ' },
];

interface CategoryForm {
  name_ar: string; name_en: string; icon: string; parent_id: number | null;
  description_ar: string; description_en: string; commission_rate: string;
  is_free: boolean; is_active: boolean;
}
const emptyForm: CategoryForm = {
  name_ar: '', name_en: '', icon: '', parent_id: null,
  description_ar: '', description_en: '', commission_rate: '',
  is_free: false, is_active: true,
};

interface FieldForm {
  field_key: string; label_ar: string; label_en: string; field_type: string;
  options: string; is_required: boolean; is_filterable: boolean;
}
const emptyFieldForm: FieldForm = {
  field_key: '', label_ar: '', label_en: '', field_type: 'text',
  options: '', is_required: false, is_filterable: false,
};

export default function AdminCategoriesPage() {
  const [categories, setCategories] = useState<AdminCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [expanded, setExpanded] = useState<number | null>(null);
  const [catModal, setCatModal] = useState<{ mode: 'create' | 'edit'; cat?: AdminCategory } | null>(null);
  const [form, setForm] = useState<CategoryForm>(emptyForm);
  const [busy, setBusy] = useState(false);
  const [fieldsModal, setFieldsModal] = useState<AdminCategory | null>(null);
  const [fields, setFields] = useState<AdminCategoryField[]>([]);
  const [fieldForm, setFieldForm] = useState<FieldForm>(emptyFieldForm);
  const [editFieldId, setEditFieldId] = useState<number | null>(null);

  const showToast = (msg: string, type: 'success' | 'error') => { setToast({ msg, type }); setTimeout(() => setToast(null), 3000); };

  const load = useCallback(async () => {
    setLoading(true);
    try { const d = await fetchAdminCategories(); setCategories(d); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleSave = async () => {
    if (!form.name_ar || !form.name_en) return;
    setBusy(true);
    try {
      const data = { ...form, commission_rate: form.commission_rate ? parseFloat(form.commission_rate) : null };
      if (catModal?.mode === 'edit' && catModal.cat) {
        await updateCategory(catModal.cat.id, data);
        showToast('تم تحديث التصنيف', 'success');
      } else {
        await createCategory(data);
        showToast('تم إنشاء التصنيف', 'success');
      }
      setCatModal(null); setForm(emptyForm); load();
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const handleToggle = async (cat: AdminCategory) => {
    try { await toggleCategory(cat.id); showToast(cat.is_active ? 'تم تعطيل التصنيف' : 'تم تفعيل التصنيف', 'success'); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
  };

  const openEdit = (cat: AdminCategory) => {
    setCatModal({ mode: 'edit', cat });
    setForm({
      name_ar: cat.name_ar, name_en: cat.name_en, icon: cat.icon || '',
      parent_id: cat.parent_id, description_ar: cat.description_ar || '',
      description_en: cat.description_en || '', commission_rate: cat.commission_rate || '',
      is_free: cat.is_free, is_active: cat.is_active,
    });
  };

  // ── Category Fields ── //
  const openFields = async (cat: AdminCategory) => {
    setFieldsModal(cat);
    try { const f = await fetchCategoryFields(cat.id); setFields(f); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
  };

  const handleFieldSave = async () => {
    if (!fieldsModal || !fieldForm.field_key || !fieldForm.label_ar) return;
    setBusy(true);
    const data = { ...fieldForm, options: fieldForm.options ? fieldForm.options.split(',').map(o => o.trim()).filter(Boolean) : null };
    try {
      if (editFieldId) {
        await updateCategoryField(editFieldId, data);
        showToast('تم تحديث الحقل', 'success');
      } else {
        await createCategoryField(fieldsModal.id, data);
        showToast('تم إضافة الحقل', 'success');
      }
      setFieldForm(emptyFieldForm); setEditFieldId(null);
      const f = await fetchCategoryFields(fieldsModal.id); setFields(f);
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const handleFieldDelete = async (fieldId: number) => {
    try { await deleteCategoryField(fieldId); showToast('تم حذف الحقل', 'success'); if (fieldsModal) { const f = await fetchCategoryFields(fieldsModal.id); setFields(f); } }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
  };

  const editField = (f: AdminCategoryField) => {
    setEditFieldId(f.id);
    setFieldForm({ field_key: f.field_key, label_ar: f.label_ar, label_en: f.label_en, field_type: f.field_type, options: f.options?.join(', ') || '', is_required: f.is_required, is_filterable: f.is_filterable });
  };

  const renderCat = (cat: AdminCategory, isChild = false) => (
    <div key={cat.id}>
      <div className={s.treeItem} style={isChild ? { paddingRight: 48 } : undefined}>
        <span className={s.treeIcon}>{cat.icon || '📂'}</span>
        <div className={s.treeInfo}>
          <div className={s.treeName}>{cat.name_ar}</div>
          <div className={s.treeSub}>{cat.name_en} · {cat.ads_count} إعلان · {cat.fields_count} حقل{cat.commission_rate ? ` · عمولة ${cat.commission_rate}%` : ''}</div>
        </div>
        <div className={s.treeActions}>
          <button className={`${s.toggle} ${cat.is_active ? s.on : ''}`} onClick={() => handleToggle(cat)} title={cat.is_active ? 'تعطيل' : 'تفعيل'} />
          <button className={`${s.btn} ${s.sm}`} onClick={() => openFields(cat)}>📋 حقول</button>
          <button className={`${s.btn} ${s.sm}`} onClick={() => openEdit(cat)}>✏️</button>
          {!isChild && cat.children && cat.children.length > 0 && (
            <button className={`${s.btn} ${s.sm}`} onClick={() => setExpanded(expanded === cat.id ? null : cat.id)}>
              {expanded === cat.id ? '▲' : '▼'} {cat.children.length}
            </button>
          )}
        </div>
      </div>
      {!isChild && expanded === cat.id && cat.children?.map(c => renderCat(c, true))}
    </div>
  );

  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {/* Category Create/Edit Modal */}
      {catModal && (
        <div className={s.modalOverlay} onClick={() => { setCatModal(null); setForm(emptyForm); }}>
          <div className={s.modal} onClick={e => e.stopPropagation()}>
            <h3 className={s.modalTitle}>{catModal.mode === 'edit' ? '✏️ تعديل التصنيف' : '➕ تصنيف جديد'}</h3>
            <div className={s.modalField}><label className={s.modalLabel}>الاسم (عربي) *</label>
              <input className={s.modalInput} value={form.name_ar} onChange={e => setForm({ ...form, name_ar: e.target.value })} /></div>
            <div className={s.modalField}><label className={s.modalLabel}>الاسم (إنجليزي) *</label>
              <input className={s.modalInput} value={form.name_en} onChange={e => setForm({ ...form, name_en: e.target.value })} /></div>
            <div className={s.modalField}><label className={s.modalLabel}>الأيقونة (emoji)</label>
              <input className={s.modalInput} value={form.icon} onChange={e => setForm({ ...form, icon: e.target.value })} placeholder="📂" /></div>
            <div className={s.modalField}><label className={s.modalLabel}>التصنيف الأب</label>
              <select className={s.modalInput} value={form.parent_id || ''} onChange={e => setForm({ ...form, parent_id: e.target.value ? Number(e.target.value) : null })}>
                <option value="">بدون (تصنيف رئيسي)</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name_ar}</option>)}
              </select></div>
            <div className={s.modalField}><label className={s.modalLabel}>نسبة العمولة (%)</label>
              <input className={s.modalInput} type="number" step="0.01" value={form.commission_rate} onChange={e => setForm({ ...form, commission_rate: e.target.value })} /></div>
            <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--admin-text-secondary)', fontSize: 13 }}>
                <input type="checkbox" checked={form.is_free} onChange={e => setForm({ ...form, is_free: e.target.checked })} /> مجاني
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--admin-text-secondary)', fontSize: 13 }}>
                <input type="checkbox" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} /> مفعّل
              </label>
            </div>
            <div className={s.modalActions}>
              <button className={`${s.btn} ${s.primary}`} onClick={handleSave} disabled={busy || !form.name_ar || !form.name_en}>حفظ</button>
              <button className={s.btn} onClick={() => { setCatModal(null); setForm(emptyForm); }}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* Fields Modal */}
      {fieldsModal && (
        <div className={s.modalOverlay} onClick={() => { setFieldsModal(null); setFields([]); setFieldForm(emptyFieldForm); setEditFieldId(null); }}>
          <div className={s.modal} onClick={e => e.stopPropagation()} style={{ maxWidth: 640 }}>
            <h3 className={s.modalTitle}>📋 حقول &quot;{fieldsModal.name_ar}&quot;</h3>
            {/* Existing Fields */}
            {fields.length > 0 && (
              <div style={{ marginBottom: 20 }}>
                {fields.map(f => (
                  <div key={f.id} className={s.treeItem} style={{ padding: '8px 0' }}>
                    <div className={s.treeInfo}>
                      <div className={s.treeName}>{f.label_ar} <span style={{ color: 'var(--admin-text-muted)', fontSize: 12 }}>({f.field_key})</span></div>
                      <div className={s.treeSub}>{FIELD_TYPES.find(t => t.value === f.field_type)?.label} · {f.is_required ? 'مطلوب' : 'اختياري'}{f.is_filterable ? ' · قابل للفلترة' : ''}</div>
                    </div>
                    <div className={s.treeActions}>
                      <button className={`${s.btn} ${s.sm}`} onClick={() => editField(f)}>✏️</button>
                      <button className={`${s.btn} ${s.danger} ${s.sm}`} onClick={() => handleFieldDelete(f.id)}>🗑️</button>
                    </div>
                  </div>
                ))}
              </div>
            )}
            {/* Add/Edit Field Form */}
            <div className={s.cardTitle}>{editFieldId ? '✏️ تعديل حقل' : '➕ إضافة حقل'}</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className={s.modalField}><label className={s.modalLabel}>المفتاح *</label>
                <input className={s.modalInput} value={fieldForm.field_key} onChange={e => setFieldForm({ ...fieldForm, field_key: e.target.value })} placeholder="year" /></div>
              <div className={s.modalField}><label className={s.modalLabel}>النوع</label>
                <select className={s.modalInput} value={fieldForm.field_type} onChange={e => setFieldForm({ ...fieldForm, field_type: e.target.value })}>
                  {FIELD_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                </select></div>
              <div className={s.modalField}><label className={s.modalLabel}>التسمية (عربي) *</label>
                <input className={s.modalInput} value={fieldForm.label_ar} onChange={e => setFieldForm({ ...fieldForm, label_ar: e.target.value })} /></div>
              <div className={s.modalField}><label className={s.modalLabel}>التسمية (إنجليزي)</label>
                <input className={s.modalInput} value={fieldForm.label_en} onChange={e => setFieldForm({ ...fieldForm, label_en: e.target.value })} /></div>
            </div>
            <div className={s.modalField}><label className={s.modalLabel}>الخيارات (للقائمة، مفصولة بفاصلة)</label>
              <input className={s.modalInput} value={fieldForm.options} onChange={e => setFieldForm({ ...fieldForm, options: e.target.value })} placeholder="جديد, مستعمل, ممتاز" /></div>
            <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--admin-text-secondary)', fontSize: 13 }}>
                <input type="checkbox" checked={fieldForm.is_required} onChange={e => setFieldForm({ ...fieldForm, is_required: e.target.checked })} /> مطلوب</label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--admin-text-secondary)', fontSize: 13 }}>
                <input type="checkbox" checked={fieldForm.is_filterable} onChange={e => setFieldForm({ ...fieldForm, is_filterable: e.target.checked })} /> قابل للفلترة</label>
            </div>
            <div className={s.modalActions}>
              <button className={`${s.btn} ${s.primary}`} onClick={handleFieldSave} disabled={busy || !fieldForm.field_key || !fieldForm.label_ar}>
                {editFieldId ? 'تحديث' : 'إضافة'}
              </button>
              {editFieldId && <button className={s.btn} onClick={() => { setEditFieldId(null); setFieldForm(emptyFieldForm); }}>إلغاء التعديل</button>}
              <button className={s.btn} onClick={() => { setFieldsModal(null); setFields([]); setFieldForm(emptyFieldForm); setEditFieldId(null); }}>إغلاق</button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className={s.pageHeader}>
        <h1 className={s.pageTitle}>📂 إدارة التصنيفات</h1>
        <button className={`${s.btn} ${s.primary}`} onClick={() => { setCatModal({ mode: 'create' }); setForm(emptyForm); }}>➕ تصنيف جديد</button>
      </div>

      {/* Tree */}
      {loading ? (
        <div className={s.loading}><div className={s.spinner} /></div>
      ) : categories.length === 0 ? (
        <div className={s.empty}><h3>لا توجد تصنيفات</h3></div>
      ) : (
        <div className={s.card} style={{ padding: 0, overflow: 'hidden' }}>
          {categories.map(cat => renderCat(cat))}
        </div>
      )}
    </div>
  );
}
