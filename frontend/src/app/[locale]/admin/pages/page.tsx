'use client';
import { useEffect, useState, useCallback, useRef } from 'react';
import { fetchAdminPages, createPage, updatePage, deletePage, type AdminStaticPage } from '@/lib/api/admin';
import s from '../admin-shared.module.css';

interface PageForm {
  title_ar: string; title_en: string; slug: string;
  content_ar: string; content_en: string;
  meta_description_ar: string; meta_description_en: string;
  is_published: boolean;
}
const emptyForm: PageForm = {
  title_ar: '', title_en: '', slug: '', content_ar: '', content_en: '',
  meta_description_ar: '', meta_description_en: '', is_published: true,
};

export default function AdminPagesPage() {
  const [pages, setPages] = useState<AdminStaticPage[]>([]);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [editorMode, setEditorMode] = useState<'list' | 'create' | 'edit'>('list');
  const [form, setForm] = useState<PageForm>(emptyForm);
  const [editId, setEditId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [activeTab, setActiveTab] = useState<'ar' | 'en'>('ar');
  const [deleteModal, setDeleteModal] = useState<AdminStaticPage | null>(null);
  const editorRef = useRef<HTMLDivElement>(null);

  const showToast = (msg: string, type: 'success' | 'error') => { setToast({ msg, type }); setTimeout(() => setToast(null), 3000); };

  const load = useCallback(async () => {
    setLoading(true);
    try { const d = await fetchAdminPages(); setPages(d); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const slugify = (text: string) => text.toLowerCase().trim().replace(/[^\w\s-]/g, '').replace(/[\s_]+/g, '-').replace(/^-+|-+$/g, '');

  const openCreate = () => { setForm(emptyForm); setEditId(null); setEditorMode('create'); setActiveTab('ar'); };
  const openEdit = (p: AdminStaticPage) => {
    setEditId(p.id);
    setForm({
      title_ar: p.title_ar, title_en: p.title_en, slug: p.slug,
      content_ar: p.content_ar, content_en: p.content_en,
      meta_description_ar: p.meta_description_ar || '', meta_description_en: p.meta_description_en || '',
      is_published: p.is_published,
    });
    setEditorMode('edit');
    setActiveTab('ar');
  };

  const handleSave = async () => {
    if (!form.title_ar || !form.slug) return;
    // Sync editor content before save
    if (editorRef.current) {
      const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
      setForm(prev => ({ ...prev, [key]: editorRef.current?.innerHTML || '' }));
    }
    setBusy(true);
    try {
      const data = { ...form };
      if (editorRef.current) {
        const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
        data[key] = editorRef.current.innerHTML;
      }
      if (editId) {
        await updatePage(editId, data);
        showToast('تم تحديث الصفحة', 'success');
      } else {
        await createPage(data);
        showToast('تم إنشاء الصفحة', 'success');
      }
      setEditorMode('list'); load();
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const handleDelete = async () => {
    if (!deleteModal) return;
    setBusy(true);
    try { await deletePage(deleteModal.id); showToast('تم حذف الصفحة', 'success'); setDeleteModal(null); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const execCmd = (cmd: string, value?: string) => {
    document.execCommand(cmd, false, value);
    editorRef.current?.focus();
  };

  const handleTabSwitch = (tab: 'ar' | 'en') => {
    if (editorRef.current) {
      const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
      setForm(prev => ({ ...prev, [key]: editorRef.current?.innerHTML || '' }));
    }
    setActiveTab(tab);
    // Set after React re-render
    setTimeout(() => {
      if (editorRef.current) {
        editorRef.current.innerHTML = tab === 'ar' ? form.content_ar : form.content_en;
      }
    }, 0);
  };

  useEffect(() => {
    if ((editorMode === 'create' || editorMode === 'edit') && editorRef.current) {
      editorRef.current.innerHTML = activeTab === 'ar' ? form.content_ar : form.content_en;
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editorMode]);

  const fmtDate = (d: string) => new Date(d).toLocaleDateString('ar-SA', { month: 'short', day: 'numeric', year: 'numeric' });

  // ── List Mode ──
  if (editorMode === 'list') return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {deleteModal && (
        <div className={s.modalOverlay} onClick={() => setDeleteModal(null)}>
          <div className={s.modal} onClick={e => e.stopPropagation()}>
            <h3 className={s.modalTitle}>🗑️ حذف الصفحة</h3>
            <p className={s.modalBody}>هل تريد حذف &quot;{deleteModal.title_ar}&quot;؟ لا يمكن التراجع.</p>
            <div className={s.modalActions}>
              <button className={`${s.btn} ${s.danger}`} onClick={handleDelete} disabled={busy}>حذف</button>
              <button className={s.btn} onClick={() => setDeleteModal(null)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      <div className={s.pageHeader}>
        <h1 className={s.pageTitle}>📄 الصفحات الثابتة</h1>
        <button className={`${s.btn} ${s.primary}`} onClick={openCreate}>➕ صفحة جديدة</button>
      </div>

      {loading ? (
        <div className={s.loading}><div className={s.spinner} /></div>
      ) : pages.length === 0 ? (
        <div className={s.empty}><h3>لا توجد صفحات ثابتة</h3><p>أنشئ صفحة &quot;من نحن&quot; أو &quot;الشروط والأحكام&quot;</p></div>
      ) : (
        <div className={s.card} style={{ padding: 0, overflow: 'hidden' }}>
          {pages.map(p => (
            <div key={p.id} className={s.treeItem}>
              <div className={s.treeInfo}>
                <div className={s.treeName}>{p.title_ar}</div>
                <div className={s.treeSub}>/{p.slug} · {p.title_en} · آخر تحديث: {fmtDate(p.updated_at)}</div>
              </div>
              <div className={s.treeActions}>
                <span className={`${s.badge} ${p.is_published ? s.green : s.gray}`}>
                  {p.is_published ? 'منشورة' : 'مسودة'}
                </span>
                <button className={`${s.btn} ${s.sm}`} onClick={() => openEdit(p)}>✏️ تعديل</button>
                <button className={`${s.btn} ${s.danger} ${s.sm}`} onClick={() => setDeleteModal(p)}>🗑️</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  // ── Editor Mode ──
  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      <div className={s.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button className={s.btn} onClick={() => setEditorMode('list')}>→ العودة</button>
          <h1 className={s.pageTitle}>{editId ? '✏️ تعديل صفحة' : '➕ صفحة جديدة'}</h1>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--admin-text-secondary)', fontSize: 13 }}>
            <input type="checkbox" checked={form.is_published} onChange={e => setForm({ ...form, is_published: e.target.checked })} /> منشورة
          </label>
          <button className={`${s.btn} ${s.primary}`} onClick={handleSave} disabled={busy || !form.title_ar || !form.slug}>💾 حفظ</button>
        </div>
      </div>

      {/* Meta Fields */}
      <div className={s.card}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
          <div className={s.modalField}><label className={s.modalLabel}>العنوان (عربي) *</label>
            <input className={s.modalInput} value={form.title_ar} onChange={e => {
              const val = e.target.value;
              setForm(prev => ({ ...prev, title_ar: val, slug: prev.slug || slugify(val) }));
            }} /></div>
          <div className={s.modalField}><label className={s.modalLabel}>العنوان (إنجليزي)</label>
            <input className={s.modalInput} value={form.title_en} onChange={e => setForm({ ...form, title_en: e.target.value })} /></div>
          <div className={s.modalField}><label className={s.modalLabel}>الرابط (slug) *</label>
            <input className={s.modalInput} value={form.slug} onChange={e => setForm({ ...form, slug: e.target.value })} style={{ direction: 'ltr' }} /></div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 12 }}>
          <div className={s.modalField}><label className={s.modalLabel}>وصف ميتا (عربي)</label>
            <input className={s.modalInput} value={form.meta_description_ar} onChange={e => setForm({ ...form, meta_description_ar: e.target.value })} /></div>
          <div className={s.modalField}><label className={s.modalLabel}>وصف ميتا (إنجليزي)</label>
            <input className={s.modalInput} value={form.meta_description_en} onChange={e => setForm({ ...form, meta_description_en: e.target.value })} /></div>
        </div>
      </div>

      {/* Content Editor */}
      <div className={s.card} style={{ padding: 0, overflow: 'hidden' }}>
        {/* Tab Headers */}
        <div style={{ display: 'flex', borderBottom: '1px solid var(--admin-border)' }}>
          <button className={`${s.chip} ${activeTab === 'ar' ? s.active : ''}`}
            style={{ borderRadius: 0, border: 'none', borderBottom: activeTab === 'ar' ? '2px solid var(--admin-accent)' : 'none' }}
            onClick={() => handleTabSwitch('ar')}>المحتوى (عربي)</button>
          <button className={`${s.chip} ${activeTab === 'en' ? s.active : ''}`}
            style={{ borderRadius: 0, border: 'none', borderBottom: activeTab === 'en' ? '2px solid var(--admin-accent)' : 'none' }}
            onClick={() => handleTabSwitch('en')}>Content (English)</button>
        </div>

        {/* Toolbar */}
        <div className={s.editorToolbar}>
          <button className={s.editorBtn} onClick={() => execCmd('bold')} title="Bold"><b>B</b></button>
          <button className={s.editorBtn} onClick={() => execCmd('italic')} title="Italic"><i>I</i></button>
          <button className={s.editorBtn} onClick={() => execCmd('underline')} title="Underline"><u>U</u></button>
          <span style={{ width: 1, background: 'var(--admin-border)', margin: '0 4px' }} />
          <button className={s.editorBtn} onClick={() => execCmd('formatBlock', 'h2')}>H2</button>
          <button className={s.editorBtn} onClick={() => execCmd('formatBlock', 'h3')}>H3</button>
          <button className={s.editorBtn} onClick={() => execCmd('formatBlock', 'p')}>P</button>
          <span style={{ width: 1, background: 'var(--admin-border)', margin: '0 4px' }} />
          <button className={s.editorBtn} onClick={() => execCmd('insertUnorderedList')}>• قائمة</button>
          <button className={s.editorBtn} onClick={() => execCmd('insertOrderedList')}>1. قائمة</button>
          <button className={s.editorBtn} onClick={() => {
            const url = prompt('رابط:');
            if (url) execCmd('createLink', url);
          }}>🔗</button>
          <button className={s.editorBtn} onClick={() => execCmd('removeFormat')}>⊘</button>
        </div>

        {/* Editable Area */}
        <div
          ref={editorRef}
          className={s.editorContent}
          contentEditable
          suppressContentEditableWarning
          style={{ direction: activeTab === 'ar' ? 'rtl' : 'ltr' }}
          onBlur={() => {
            if (editorRef.current) {
              const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
              setForm(prev => ({ ...prev, [key]: editorRef.current?.innerHTML || '' }));
            }
          }}
        />
      </div>
    </div>
  );
}
