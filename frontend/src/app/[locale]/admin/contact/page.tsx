'use client';

import { useEffect, useState, useCallback } from 'react';
import {
  fetchAdminContacts,
  updateContactStatus,
  type ContactSubmission,
} from '@/lib/api/contact';
import s from '../admin-shared.module.css';

const STATUS_LABELS: Record<string, string> = {
  pending:     'في الانتظار',
  in_progress: 'قيد المعالجة',
  resolved:    'تم الحل',
};

const STATUS_COLORS: Record<string, string> = {
  pending:     '#f59e0b',
  in_progress: '#3b82f6',
  resolved:    '#16a34a',
};

export default function AdminContactPage() {
  const [submissions, setSubmissions] = useState<ContactSubmission[]>([]);
  const [meta, setMeta] = useState({ current_page: 1, last_page: 1, total: 0 });
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [search, setSearch] = useState('');
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [modal, setModal] = useState<ContactSubmission | null>(null);
  const [newStatus, setNewStatus] = useState<'pending' | 'in_progress' | 'resolved'>('pending');
  const [adminNote, setAdminNote] = useState('');
  const [busy, setBusy] = useState(false);

  const showToast = (msg: string, type: 'success' | 'error') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  };

  const load = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const res = await fetchAdminContacts({
        status:   statusFilter || undefined,
        search:   search || undefined,
        page,
        per_page: 20,
      });
      setSubmissions(res.data);
      setMeta(res.meta);
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ في التحميل', 'error');
    } finally {
      setLoading(false);
    }
  }, [statusFilter, search]);

  useEffect(() => { load(); }, [load]);

  const openModal = (s: ContactSubmission) => {
    setModal(s);
    setNewStatus(s.status);
    setAdminNote(s.admin_note ?? '');
  };

  const handleUpdate = async () => {
    if (!modal) return;
    setBusy(true);
    try {
      await updateContactStatus(modal.id, { status: newStatus, admin_note: adminNote || undefined });
      showToast('تم تحديث الحالة بنجاح', 'success');
      setModal(null);
      load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const fmtDate = (d: string) =>
    new Date(d).toLocaleDateString('ar-SA', {
      month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
    });

  return (
    <div className={s.page}>
      <div className={s.header}>
        <h1 className={s.title}>رسائل تواصل معنا</h1>
        <span className={s.badge}>{meta.total} رسالة</span>
      </div>

      {/* Filters */}
      <div className={s.filters}>
        <select
          className={s.select}
          value={statusFilter}
          onChange={e => { setStatusFilter(e.target.value); }}
        >
          <option value="">كل الحالات</option>
          <option value="pending">في الانتظار</option>
          <option value="in_progress">قيد المعالجة</option>
          <option value="resolved">تم الحل</option>
        </select>
        <input
          className={s.searchInput}
          placeholder="ابحث بالاسم أو البريد..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && load()}
        />
      </div>

      {toast && (
        <div className={`${s.toast} ${toast.type === 'success' ? s.toastSuccess : s.toastError}`}>
          {toast.msg}
        </div>
      )}

      {loading ? (
        <div className={s.loading}>جارٍ التحميل...</div>
      ) : submissions.length === 0 ? (
        <div className={s.empty}>لا توجد رسائل</div>
      ) : (
        <div className={s.tableWrap}>
          <table className={s.table}>
            <thead>
              <tr>
                <th>#</th>
                <th>المرسل</th>
                <th>الفئة</th>
                <th>الرسالة</th>
                <th>الحالة</th>
                <th>التاريخ</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              {submissions.map(sub => (
                <tr key={sub.id}>
                  <td>{sub.id}</td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{sub.name}</div>
                    <div style={{ fontSize: '0.78rem', color: '#757575' }}>{sub.email}</div>
                    {sub.phone && (
                      <div style={{ fontSize: '0.78rem', color: '#757575' }}>{sub.phone}</div>
                    )}
                  </td>
                  <td style={{ fontSize: '0.82rem', maxWidth: 160 }}>{sub.category_label}</td>
                  <td style={{ maxWidth: 240, fontSize: '0.85rem' }}>
                    {sub.message.length > 80 ? sub.message.slice(0, 80) + '...' : sub.message}
                  </td>
                  <td>
                    <span
                      className={s.statusBadge}
                      style={{ background: STATUS_COLORS[sub.status] + '22', color: STATUS_COLORS[sub.status] }}
                    >
                      {STATUS_LABELS[sub.status]}
                    </span>
                  </td>
                  <td style={{ fontSize: '0.82rem', color: '#757575' }}>{fmtDate(sub.created_at)}</td>
                  <td>
                    <button className={s.actionBtn} onClick={() => openModal(sub)}>
                      معالجة
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {meta.last_page > 1 && (
        <div className={s.pagination}>
          {Array.from({ length: meta.last_page }, (_, i) => i + 1).map(p => (
            <button
              key={p}
              className={`${s.pageBtn} ${p === meta.current_page ? s.pageBtnActive : ''}`}
              onClick={() => load(p)}
            >
              {p}
            </button>
          ))}
        </div>
      )}

      {/* Modal */}
      {modal && (
        <div className={s.overlay} onClick={() => setModal(null)}>
          <div className={s.modal} onClick={e => e.stopPropagation()}>
            <h2 className={s.modalTitle}>معالجة رسالة #{modal.id}</h2>

            <div className={s.modalSection}>
              <strong>المرسل:</strong> {modal.name} — {modal.email}
              {modal.phone && <span> — {modal.phone}</span>}
            </div>
            <div className={s.modalSection}>
              <strong>الفئة:</strong> {modal.category_label}
            </div>
            <div className={s.modalSection}>
              <strong>الرسالة:</strong>
              <p style={{ margin: '0.4rem 0 0', lineHeight: 1.6 }}>{modal.message}</p>
            </div>

            <div className={s.modalSection}>
              <label className={s.modalLabel}>الحالة</label>
              <select
                className={s.select}
                value={newStatus}
                onChange={e => setNewStatus(e.target.value as typeof newStatus)}
              >
                <option value="pending">في الانتظار</option>
                <option value="in_progress">قيد المعالجة</option>
                <option value="resolved">تم الحل</option>
              </select>
            </div>

            <div className={s.modalSection}>
              <label className={s.modalLabel}>ملاحظة الإدارة (اختياري)</label>
              <textarea
                className={s.textarea}
                rows={3}
                value={adminNote}
                onChange={e => setAdminNote(e.target.value)}
                placeholder="أضف ملاحظة داخلية..."
              />
            </div>

            <div className={s.modalActions}>
              <button className={s.btnSecondary} onClick={() => setModal(null)}>إلغاء</button>
              <button className={s.btnPrimary} onClick={handleUpdate} disabled={busy}>
                {busy ? 'جارٍ الحفظ...' : 'حفظ'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
