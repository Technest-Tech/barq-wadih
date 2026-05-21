'use client';
import { useEffect, useState, useCallback, useRef } from 'react';
import {
  fetchAdminPages,
  createPage,
  updatePage,
  deletePage,
  type AdminStaticPage,
} from '@/lib/api/admin';
import s from '../admin-shared.module.css';

// ── Known pages quick-access ───────────────────────────────────────────────
const KNOWN_PAGES = [
  { slug: 'terms', labelAr: 'الشروط والأحكام', path: '/ar/terms' },
  { slug: 'privacy', labelAr: 'سياسة الخصوصية', path: '/ar/privacy' },
  { slug: 'fees', labelAr: 'الرسوم والأسعار', path: '/ar/fees' },
  { slug: 'how-we-buy', labelAr: 'كيف نشتري', path: '/ar/how-we-buy' },
  { slug: 'how-we-sell', labelAr: 'كيف نبيع', path: '/ar/how-we-sell' },
  { slug: 'contact-info', labelAr: 'معلومات التواصل', path: '/ar/contact' },
];

// ── Types ──────────────────────────────────────────────────────────────────
interface PageForm {
  title_ar: string;
  title_en: string;
  slug: string;
  content_ar: string;
  content_en: string;
  meta_description_ar: string;
  meta_description_en: string;
  is_published: boolean;
}
const emptyForm: PageForm = {
  title_ar: '',
  title_en: '',
  slug: '',
  content_ar: '',
  content_en: '',
  meta_description_ar: '',
  meta_description_en: '',
  is_published: true,
};

interface TableBuilder {
  open: boolean;
  headers: string[];
  rows: string[][];
}
const defaultTable = (): TableBuilder => ({
  open: false,
  headers: ['الفئة', 'فرد', 'تاجر'],
  rows: [
    ['السيارات والمركبات', 'مجاني', '99 ر.س / شهر'],
    ['العقارات', '49 ر.س', '149 ر.س / شهر'],
    ['الإلكترونيات', 'مجاني', '49 ر.س / شهر'],
  ],
});

// ── Parse an existing <table> from HTML string ─────────────────────────────
function parseTableFromHtml(html: string): { headers: string[]; rows: string[][] } | null {
  if (typeof window === 'undefined') return null;
  const div = document.createElement('div');
  div.innerHTML = html;
  const tableEl = div.querySelector('table');
  if (!tableEl) return null;
  const headers = Array.from(tableEl.querySelectorAll('thead th')).map(
    (th) => (th as HTMLElement).innerText ?? th.textContent ?? ''
  );
  if (headers.length === 0) return null;
  const rows = Array.from(tableEl.querySelectorAll('tbody tr')).map((tr) =>
    Array.from(tr.querySelectorAll('td')).map(
      (td) => (td as HTMLElement).innerText ?? td.textContent ?? ''
    )
  );
  return { headers, rows };
}

// ── Generate HTML table ────────────────────────────────────────────────────
function buildTableHtml(headers: string[], rows: string[][]): string {
  const thStyle =
    'padding:10px 14px;text-align:right;border:1px solid #e5e7eb;font-weight:600;background:#f3f4f6;';
  const tdStyle = 'padding:10px 14px;border:1px solid #e5e7eb;';
  const ths = headers.map((h) => `<th style="${thStyle}">${h}</th>`).join('');
  const trs = rows
    .map((row) => {
      const tds = row.map((c) => `<td style="${tdStyle}">${c}</td>`).join('');
      return `<tr>${tds}</tr>`;
    })
    .join('');
  return `<table style="width:100%;border-collapse:collapse;margin:16px 0;"><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>`;
}

// ── Component ──────────────────────────────────────────────────────────────
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
  const [table, setTable] = useState<TableBuilder>(defaultTable());
  const editorRef = useRef<HTMLDivElement>(null);

  const showToast = (msg: string, type: 'success' | 'error') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const d = await fetchAdminPages();
      setPages(d);
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const slugify = (t: string) =>
    t
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, '')
      .replace(/[\s_]+/g, '-')
      .replace(/^-+|-+$/g, '');

  const openCreate = () => {
    setForm(emptyForm);
    setEditId(null);
    setEditorMode('create');
    setActiveTab('ar');
    setTable(defaultTable());
  };
  const openEdit = (p: AdminStaticPage) => {
    setEditId(p.id);
    setForm({
      title_ar: p.title_ar,
      title_en: p.title_en,
      slug: p.slug,
      content_ar: p.content_ar,
      content_en: p.content_en,
      meta_description_ar: p.meta_description_ar || '',
      meta_description_en: p.meta_description_en || '',
      is_published: p.is_published,
    });
    setEditorMode('edit');
    setActiveTab('ar');
    setTable(defaultTable());
  };

  const syncEditor = () => {
    if (editorRef.current) {
      const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
      setForm((prev) => ({ ...prev, [key]: editorRef.current?.innerHTML || '' }));
    }
  };

  const handleSave = async () => {
    if (!form.title_ar || !form.slug) return;
    // Read latest innerHTML directly — don't rely on setState having flushed
    const latestContent = editorRef.current?.innerHTML ?? '';
    const contentKey = activeTab === 'ar' ? 'content_ar' : 'content_en';
    setBusy(true);
    try {
      const data = { ...form, [contentKey]: latestContent };
      if (editId) {
        await updatePage(editId, data);
        showToast('تم تحديث الصفحة', 'success');
      } else {
        await createPage(data);
        showToast('تم إنشاء الصفحة', 'success');
      }
      setEditorMode('list');
      load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteModal) return;
    setBusy(true);
    try {
      await deletePage(deleteModal.id);
      showToast('تم حذف الصفحة', 'success');
      setDeleteModal(null);
      load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const execCmd = (cmd: string, value?: string) => {
    document.execCommand(cmd, false, value);
    editorRef.current?.focus();
  };

  const handleTabSwitch = (tab: 'ar' | 'en') => {
    if (editorRef.current) {
      const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
      setForm((prev) => ({ ...prev, [key]: editorRef.current?.innerHTML || '' }));
    }
    setActiveTab(tab);
    setTimeout(() => {
      if (editorRef.current)
        editorRef.current.innerHTML = tab === 'ar' ? form.content_ar : form.content_en;
    }, 0);
  };

  useEffect(() => {
    if ((editorMode === 'create' || editorMode === 'edit') && editorRef.current)
      editorRef.current.innerHTML = activeTab === 'ar' ? form.content_ar : form.content_en;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editorMode]);

  // ── Table builder helpers ─────────────────────────────────────────────────
  const tbl = {
    open: () => {
      const parsed = parseTableFromHtml(editorRef.current?.innerHTML ?? '');
      if (parsed && parsed.headers.length > 0) {
        setTable({ open: true, headers: parsed.headers, rows: parsed.rows });
      } else {
        setTable({ ...defaultTable(), open: true });
      }
    },
    close: () => setTable((t) => ({ ...t, open: false })),

    setHeader: (ci: number, v: string) =>
      setTable((t) => {
        const h = [...t.headers];
        h[ci] = v;
        return { ...t, headers: h };
      }),

    setCell: (ri: number, ci: number, v: string) =>
      setTable((t) => {
        const rows = t.rows.map((r) => [...r]);
        rows[ri][ci] = v;
        return { ...t, rows };
      }),

    addRow: () => setTable((t) => ({ ...t, rows: [...t.rows, t.headers.map(() => '')] })),

    removeRow: (ri: number) => setTable((t) => ({ ...t, rows: t.rows.filter((_, i) => i !== ri) })),

    moveUp: (ri: number) =>
      setTable((t) => {
        if (ri === 0) return t;
        const rows = [...t.rows];
        [rows[ri - 1], rows[ri]] = [rows[ri], rows[ri - 1]];
        return { ...t, rows };
      }),

    moveDown: (ri: number) =>
      setTable((t) => {
        if (ri === t.rows.length - 1) return t;
        const rows = [...t.rows];
        [rows[ri], rows[ri + 1]] = [rows[ri + 1], rows[ri]];
        return { ...t, rows };
      }),

    addCol: () =>
      setTable((t) => ({
        ...t,
        headers: [...t.headers, `عمود ${t.headers.length + 1}`],
        rows: t.rows.map((r) => [...r, '']),
      })),

    removeCol: (ci: number) =>
      setTable((t) => ({
        ...t,
        headers: t.headers.filter((_, i) => i !== ci),
        rows: t.rows.map((r) => r.filter((_, i) => i !== ci)),
      })),

    insert: () => {
      const html = buildTableHtml(table.headers, table.rows);
      if (editorRef.current) {
        const existing = editorRef.current.querySelector('table');
        if (existing) {
          // Replace the existing table in-place
          const wrapper = document.createElement('div');
          wrapper.innerHTML = html;
          const newTable = wrapper.firstElementChild;
          if (newTable) existing.replaceWith(newTable);
        } else {
          editorRef.current.insertAdjacentHTML('beforeend', html);
        }
        const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
        setForm((prev) => ({ ...prev, [key]: editorRef.current!.innerHTML }));
      }
      setTable((t) => ({ ...t, open: false }));
    },

    reset: () => setTable(defaultTable()),
  };

  const fmtDate = (d: string) =>
    new Date(d).toLocaleDateString('ar-SA', { month: 'short', day: 'numeric', year: 'numeric' });

  // ── List Mode ─────────────────────────────────────────────────────────────
  if (editorMode === 'list')
    return (
      <div className={s.page}>
        {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

        {deleteModal && (
          <div className={s.modalOverlay} onClick={() => setDeleteModal(null)}>
            <div className={s.modal} onClick={(e) => e.stopPropagation()}>
              <h3 className={s.modalTitle}>🗑️ حذف الصفحة</h3>
              <p className={s.modalBody}>
                هل تريد حذف &quot;{deleteModal.title_ar}&quot;؟ لا يمكن التراجع.
              </p>
              <div className={s.modalActions}>
                <button className={`${s.btn} ${s.danger}`} onClick={handleDelete} disabled={busy}>
                  حذف
                </button>
                <button className={s.btn} onClick={() => setDeleteModal(null)}>
                  إلغاء
                </button>
              </div>
            </div>
          </div>
        )}

        <div className={s.pageHeader}>
          <h1 className={s.pageTitle}>📄 الصفحات الثابتة</h1>
          <button className={`${s.btn} ${s.primary}`} onClick={openCreate}>
            ➕ صفحة جديدة
          </button>
        </div>

        {/* Quick-access */}
        <div className={s.card} style={{ marginBottom: 16 }}>
          <div className={s.cardTitle}>⚡ الصفحات الرئيسية للموقع</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {KNOWN_PAGES.map((kp) => {
              const existing = pages.find((p) => p.slug === kp.slug);
              return (
                <div
                  key={kp.slug}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                    background: 'rgba(255,255,255,0.04)',
                    border: '1px solid var(--admin-border)',
                    borderRadius: 8,
                    padding: '6px 12px',
                  }}
                >
                  <span style={{ fontSize: 13, color: 'var(--admin-text)' }}>{kp.labelAr}</span>
                  {existing ? (
                    <>
                      <span
                        className={`${s.badge} ${existing.is_published ? s.green : s.gray}`}
                        style={{ fontSize: 10 }}
                      >
                        {existing.is_published ? '✓' : 'مسودة'}
                      </span>
                      <button
                        className={`${s.btn} ${s.sm}`}
                        style={{ padding: '2px 8px', fontSize: 11 }}
                        onClick={() => openEdit(existing)}
                      >
                        تعديل
                      </button>
                      <a
                        href={kp.path}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={s.btn}
                        style={{ padding: '2px 8px', fontSize: 11, textDecoration: 'none' }}
                      >
                        عرض ↗
                      </a>
                    </>
                  ) : (
                    <button
                      className={`${s.btn} ${s.primary} ${s.sm}`}
                      style={{ padding: '2px 8px', fontSize: 11 }}
                      onClick={() => {
                        setForm({ ...emptyForm, slug: kp.slug, title_ar: kp.labelAr });
                        setEditId(null);
                        setEditorMode('create');
                        setActiveTab('ar');
                      }}
                    >
                      ➕ إنشاء
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {loading ? (
          <div className={s.loading}>
            <div className={s.spinner} />
          </div>
        ) : pages.length === 0 ? (
          <div className={s.empty}>
            <h3>لا توجد صفحات ثابتة</h3>
            <p>استخدم الاختصارات أعلاه أو أنشئ صفحة جديدة</p>
          </div>
        ) : (
          <div className={s.card} style={{ padding: 0, overflow: 'hidden' }}>
            {pages.map((p) => {
              const kp = KNOWN_PAGES.find((x) => x.slug === p.slug);
              return (
                <div key={p.id} className={s.treeItem}>
                  <div className={s.treeInfo}>
                    <div className={s.treeName}>{p.title_ar}</div>
                    <div className={s.treeSub}>
                      /{p.slug} · {p.title_en} · آخر تحديث: {fmtDate(p.updated_at)}
                    </div>
                  </div>
                  <div className={s.treeActions}>
                    <span className={`${s.badge} ${p.is_published ? s.green : s.gray}`}>
                      {p.is_published ? 'منشورة' : 'مسودة'}
                    </span>
                    {kp && (
                      <a
                        href={kp.path}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={s.btn}
                        style={{ textDecoration: 'none', fontSize: 12 }}
                      >
                        ↗ عرض
                      </a>
                    )}
                    <button className={`${s.btn} ${s.sm}`} onClick={() => openEdit(p)}>
                      ✏️ تعديل
                    </button>
                    <button
                      className={`${s.btn} ${s.danger} ${s.sm}`}
                      onClick={() => setDeleteModal(p)}
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    );

  // ── Editor Mode ───────────────────────────────────────────────────────────
  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      <div className={s.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button className={s.btn} onClick={() => setEditorMode('list')}>
            → العودة
          </button>
          <h1 className={s.pageTitle}>{editId ? '✏️ تعديل صفحة' : '➕ صفحة جديدة'}</h1>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <label
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              color: 'var(--admin-text-secondary)',
              fontSize: 13,
            }}
          >
            <input
              type="checkbox"
              checked={form.is_published}
              onChange={(e) => setForm({ ...form, is_published: e.target.checked })}
            />{' '}
            منشورة
          </label>
          <button
            className={`${s.btn} ${s.primary}`}
            onClick={handleSave}
            disabled={busy || !form.title_ar || !form.slug}
          >
            💾 حفظ
          </button>
        </div>
      </div>

      {/* Meta fields */}
      <div className={s.card}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
          <div className={s.modalField}>
            <label className={s.modalLabel}>العنوان (عربي) *</label>
            <input
              className={s.modalInput}
              value={form.title_ar}
              onChange={(e) => {
                const val = e.target.value;
                setForm((prev) => ({ ...prev, title_ar: val, slug: prev.slug || slugify(val) }));
              }}
            />
          </div>
          <div className={s.modalField}>
            <label className={s.modalLabel}>العنوان (إنجليزي)</label>
            <input
              className={s.modalInput}
              value={form.title_en}
              onChange={(e) => setForm({ ...form, title_en: e.target.value })}
            />
          </div>
          <div className={s.modalField}>
            <label className={s.modalLabel}>الرابط (slug) *</label>
            <input
              className={s.modalInput}
              value={form.slug}
              onChange={(e) => setForm({ ...form, slug: e.target.value })}
              style={{ direction: 'ltr' }}
            />
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 12 }}>
          <div className={s.modalField}>
            <label className={s.modalLabel}>وصف ميتا (عربي)</label>
            <input
              className={s.modalInput}
              value={form.meta_description_ar}
              onChange={(e) => setForm({ ...form, meta_description_ar: e.target.value })}
            />
          </div>
          <div className={s.modalField}>
            <label className={s.modalLabel}>وصف ميتا (إنجليزي)</label>
            <input
              className={s.modalInput}
              value={form.meta_description_en}
              onChange={(e) => setForm({ ...form, meta_description_en: e.target.value })}
            />
          </div>
        </div>
      </div>

      {/* Content editor */}
      <div className={s.card} style={{ padding: 0, overflow: 'hidden' }}>
        {/* Lang tabs */}
        <div style={{ display: 'flex', borderBottom: '1px solid var(--admin-border)' }}>
          {(['ar', 'en'] as const).map((lang) => (
            <button
              key={lang}
              className={`${s.chip} ${activeTab === lang ? s.active : ''}`}
              style={{
                borderRadius: 0,
                border: 'none',
                borderBottom: activeTab === lang ? '2px solid var(--admin-accent)' : 'none',
              }}
              onClick={() => handleTabSwitch(lang)}
            >
              {lang === 'ar' ? 'المحتوى (عربي)' : 'Content (English)'}
            </button>
          ))}
        </div>

        {/* Toolbar */}
        <div className={s.editorToolbar}>
          <button className={s.editorBtn} onClick={() => execCmd('bold')}>
            <b>B</b>
          </button>
          <button className={s.editorBtn} onClick={() => execCmd('italic')}>
            <i>I</i>
          </button>
          <button className={s.editorBtn} onClick={() => execCmd('underline')}>
            <u>U</u>
          </button>
          <span style={{ width: 1, background: 'var(--admin-border)', margin: '0 4px' }} />
          <button className={s.editorBtn} onClick={() => execCmd('formatBlock', 'h2')}>
            H2
          </button>
          <button className={s.editorBtn} onClick={() => execCmd('formatBlock', 'h3')}>
            H3
          </button>
          <button className={s.editorBtn} onClick={() => execCmd('formatBlock', 'p')}>
            P
          </button>
          <span style={{ width: 1, background: 'var(--admin-border)', margin: '0 4px' }} />
          <button className={s.editorBtn} onClick={() => execCmd('insertUnorderedList')}>
            • قائمة
          </button>
          <button className={s.editorBtn} onClick={() => execCmd('insertOrderedList')}>
            1. قائمة
          </button>
          <button
            className={s.editorBtn}
            onClick={() => {
              const url = prompt('رابط:');
              if (url) execCmd('createLink', url);
            }}
          >
            🔗
          </button>
          <button className={s.editorBtn} onClick={() => execCmd('removeFormat')}>
            ⊘
          </button>
          <span style={{ width: 1, background: 'var(--admin-border)', margin: '0 4px' }} />
          {/* Prices table button */}
          <button
            className={s.editorBtn}
            onClick={() => (table.open ? tbl.close() : tbl.open())}
            style={{
              background: table.open ? 'var(--admin-accent)' : undefined,
              color: table.open ? '#fff' : undefined,
              fontWeight: 700,
            }}
            title="محرر جدول الأسعار"
          >
            🗂 جدول أسعار
          </button>
        </div>

        {/* ── Prices Table Builder ── */}
        {table.open && (
          <div
            style={{
              borderTop: '2px solid var(--admin-accent)',
              background: 'rgba(99,102,241,0.04)',
              padding: 16,
            }}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                marginBottom: 14,
                flexWrap: 'wrap',
                gap: 8,
              }}
            >
              <span style={{ fontWeight: 700, fontSize: 14, color: 'var(--admin-text)' }}>
                🗂 محرر جدول الأسعار
              </span>
              <div style={{ display: 'flex', gap: 6 }}>
                <button
                  className={`${s.btn} ${s.sm}`}
                  onClick={tbl.addCol}
                  style={{
                    background: 'rgba(99,102,241,0.15)',
                    color: 'var(--admin-accent)',
                    border: '1px solid var(--admin-accent)',
                  }}
                >
                  ＋ عمود
                </button>
                <button
                  className={`${s.btn} ${s.sm}`}
                  onClick={tbl.addRow}
                  style={{
                    background: 'rgba(34,197,94,0.12)',
                    color: '#4ade80',
                    border: '1px solid #4ade80',
                  }}
                >
                  ＋ صف
                </button>
                <button
                  className={`${s.btn} ${s.sm}`}
                  onClick={tbl.reset}
                  style={{ background: 'rgba(148,163,184,0.1)', color: 'var(--admin-text-muted)' }}
                >
                  إعادة تعيين
                </button>
                <button className={`${s.btn} ${s.primary} ${s.sm}`} onClick={tbl.insert}>
                  ↩ إدراج في المحتوى
                </button>
                <button
                  className={`${s.btn} ${s.sm}`}
                  onClick={tbl.close}
                  style={{ color: 'var(--admin-text-muted)' }}
                >
                  ✕
                </button>
              </div>
            </div>

            {/* Table grid */}
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
                <thead>
                  <tr>
                    {/* Row controls column */}
                    <th
                      style={{
                        width: 72,
                        padding: '6px 4px',
                        color: 'var(--admin-text-muted)',
                        fontSize: 11,
                        fontWeight: 500,
                        textAlign: 'center',
                        background: 'rgba(0,0,0,0.08)',
                        border: '1px solid var(--admin-border)',
                      }}
                    >
                      ترتيب
                    </th>
                    {table.headers.map((h, ci) => (
                      <th
                        key={ci}
                        style={{
                          padding: '4px 6px',
                          border: '1px solid var(--admin-border)',
                          background: 'rgba(99,102,241,0.12)',
                          minWidth: 110,
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                          <input
                            value={h}
                            onChange={(e) => tbl.setHeader(ci, e.target.value)}
                            placeholder={`رأس ${ci + 1}`}
                            style={{
                              flex: 1,
                              background: 'transparent',
                              border: 'none',
                              outline: 'none',
                              color: 'var(--admin-text)',
                              fontWeight: 700,
                              fontSize: 13,
                              fontFamily: 'inherit',
                              padding: '4px 6px',
                              borderRadius: 4,
                              minWidth: 0,
                            }}
                          />
                          {table.headers.length > 1 && (
                            <button
                              onClick={() => tbl.removeCol(ci)}
                              title="حذف العمود"
                              style={{
                                background: 'none',
                                border: 'none',
                                cursor: 'pointer',
                                color: '#f87171',
                                fontSize: 14,
                                padding: '0 2px',
                                lineHeight: 1,
                              }}
                            >
                              ✕
                            </button>
                          )}
                        </div>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {table.rows.map((row, ri) => (
                    <tr key={ri}>
                      {/* Row action controls */}
                      <td
                        style={{
                          padding: '4px 4px',
                          border: '1px solid var(--admin-border)',
                          background: 'rgba(0,0,0,0.04)',
                          textAlign: 'center',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            gap: 2,
                          }}
                        >
                          <button
                            onClick={() => tbl.moveUp(ri)}
                            disabled={ri === 0}
                            title="تحريك للأعلى"
                            style={{
                              background: 'none',
                              border: 'none',
                              cursor: ri === 0 ? 'not-allowed' : 'pointer',
                              color: ri === 0 ? 'var(--admin-text-muted)' : 'var(--admin-accent)',
                              fontSize: 14,
                              padding: '2px 3px',
                              opacity: ri === 0 ? 0.3 : 1,
                            }}
                          >
                            ▲
                          </button>
                          <button
                            onClick={() => tbl.moveDown(ri)}
                            disabled={ri === table.rows.length - 1}
                            title="تحريك للأسفل"
                            style={{
                              background: 'none',
                              border: 'none',
                              cursor: ri === table.rows.length - 1 ? 'not-allowed' : 'pointer',
                              color:
                                ri === table.rows.length - 1
                                  ? 'var(--admin-text-muted)'
                                  : 'var(--admin-accent)',
                              fontSize: 14,
                              padding: '2px 3px',
                              opacity: ri === table.rows.length - 1 ? 0.3 : 1,
                            }}
                          >
                            ▼
                          </button>
                          <button
                            onClick={() => tbl.removeRow(ri)}
                            title="حذف الصف"
                            style={{
                              background: 'none',
                              border: 'none',
                              cursor: 'pointer',
                              color: '#f87171',
                              fontSize: 14,
                              padding: '2px 3px',
                            }}
                          >
                            🗑
                          </button>
                        </div>
                      </td>
                      {row.map((cell, ci) => (
                        <td
                          key={ci}
                          style={{ padding: '3px 4px', border: '1px solid var(--admin-border)' }}
                        >
                          <input
                            value={cell}
                            onChange={(e) => tbl.setCell(ri, ci, e.target.value)}
                            placeholder="—"
                            style={{
                              width: '100%',
                              background: 'transparent',
                              border: 'none',
                              outline: 'none',
                              color: 'var(--admin-text)',
                              fontSize: 13,
                              fontFamily: 'inherit',
                              padding: '5px 8px',
                              borderRadius: 4,
                              boxSizing: 'border-box',
                            }}
                            onFocus={(e) => (e.target.style.background = 'rgba(255,255,255,0.06)')}
                            onBlur={(e) => (e.target.style.background = 'transparent')}
                          />
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Preview */}
            <details style={{ marginTop: 14 }}>
              <summary
                style={{
                  cursor: 'pointer',
                  fontSize: 12,
                  color: 'var(--admin-text-muted)',
                  userSelect: 'none',
                }}
              >
                معاينة الجدول
              </summary>
              <div
                style={{
                  marginTop: 8,
                  background: '#fff',
                  borderRadius: 8,
                  padding: 12,
                  overflow: 'auto',
                }}
                dangerouslySetInnerHTML={{ __html: buildTableHtml(table.headers, table.rows) }}
              />
            </details>
          </div>
        )}

        {/* Editable content area */}
        <div
          ref={editorRef}
          className={s.editorContent}
          contentEditable
          suppressContentEditableWarning
          style={{ direction: activeTab === 'ar' ? 'rtl' : 'ltr' }}
          onBlur={() => {
            if (editorRef.current) {
              const key = activeTab === 'ar' ? 'content_ar' : 'content_en';
              setForm((prev) => ({ ...prev, [key]: editorRef.current?.innerHTML || '' }));
            }
          }}
        />
      </div>
    </div>
  );
}
