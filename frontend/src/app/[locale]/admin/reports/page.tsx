'use client';
import { useEffect, useState, useCallback } from 'react';
import { fetchAdminReports, resolveReport, dismissReport, type AdminReport } from '@/lib/api/admin';
import s from '../admin-shared.module.css';

const REASON_LABELS: Record<string, string> = {
  fake: 'إعلان مزيف', spam: 'إعلان مزعج', prohibited_content: 'محتوى محظور',
  wrong_category: 'تصنيف خاطئ', duplicate_ad: 'إعلان مكرر', scam_or_fraud: 'احتيال',
  inappropriate_images: 'صور غير لائقة', other: 'أخرى',
};
const ACTION_OPTIONS = [
  { value: 'no_action', label: 'بدون إجراء' },
  { value: 'ad_removed', label: 'حذف الإعلان' },
  { value: 'user_warned', label: 'تحذير المستخدم' },
  { value: 'user_banned', label: 'حظر المستخدم' },
];

export default function AdminReportsPage() {
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [meta, setMeta] = useState({ current_page: 1, last_page: 1, per_page: 20, total: 0 });
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [resolveModal, setResolveModal] = useState<AdminReport | null>(null);
  const [action, setAction] = useState('no_action');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);

  const showToast = (msg: string, type: 'success' | 'error') => { setToast({ msg, type }); setTimeout(() => setToast(null), 3000); };

  const load = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const r = await fetchAdminReports({ status: statusFilter || undefined, page, sort: 'priority' });
      setReports(r.data); setMeta(r.meta);
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setLoading(false); }
  }, [statusFilter]);

  useEffect(() => { load(); }, [load]);

  const handleResolve = async () => {
    if (!resolveModal) return;
    setBusy(true);
    try {
      await resolveReport(resolveModal.id, { admin_action: action, admin_note: note || undefined });
      showToast('تم معالجة البلاغ بنجاح', 'success');
      setResolveModal(null); setAction('no_action'); setNote(''); load();
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const handleDismiss = async (report: AdminReport) => {
    setBusy(true);
    try { await dismissReport(report.id); showToast('تم رفض البلاغ', 'success'); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(false); }
  };

  const fmtDate = (d: string) => new Date(d).toLocaleDateString('ar-SA', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  const pendingCount = reports.filter(r => r.status === 'pending').length;

  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {/* Resolve Modal */}
      {resolveModal && (
        <div className={s.modalOverlay} onClick={() => setResolveModal(null)}>
          <div className={s.modal} onClick={e => e.stopPropagation()}>
            <h3 className={s.modalTitle}>⚖️ معالجة البلاغ</h3>
            <p className={s.modalBody}>
              البلاغ على: &quot;{resolveModal.ad?.title || '—'}&quot;<br />
              السبب: {REASON_LABELS[resolveModal.reason] || resolveModal.reason}
              {resolveModal.description && <><br/>التفاصيل: {resolveModal.description}</>}
            </p>
            <div className={s.modalField}>
              <label className={s.modalLabel}>الإجراء الإداري</label>
              <select className={s.modalInput} value={action} onChange={e => setAction(e.target.value)}>
                {ACTION_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
            </div>
            <div className={s.modalField}>
              <label className={s.modalLabel}>ملاحظة إدارية</label>
              <textarea className={s.modalTextarea} value={note} onChange={e => setNote(e.target.value)} placeholder="ملاحظة..." />
            </div>
            <div className={s.modalActions}>
              <button className={`${s.btn} ${s.primary}`} onClick={handleResolve} disabled={busy}>تأكيد المعالجة</button>
              <button className={s.btn} onClick={() => setResolveModal(null)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className={s.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <h1 className={s.pageTitle}>البلاغات</h1>
          <span className={s.totalBadge}>{meta.total} بلاغ</span>
          {pendingCount > 0 && <span className={`${s.badge} ${s.red}`} style={{ marginRight: 8 }}>{pendingCount} معلق</span>}
        </div>
      </div>

      {/* Filter Chips */}
      <div className={s.filterBar}>
        <div className={s.filterRow}>
          {[{ v: '', l: 'الكل' }, { v: 'pending', l: '⏳ معلق' }, { v: 'resolved', l: '✅ تم الحل' }, { v: 'dismissed', l: '❌ مرفوض' }].map(f => (
            <button key={f.v} className={`${s.chip} ${statusFilter === f.v ? s.active : ''}`} onClick={() => { setStatusFilter(f.v); }}>
              {f.l}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className={s.loading}><div className={s.spinner} /><span>جاري التحميل...</span></div>
      ) : reports.length === 0 ? (
        <div className={s.empty}><h3>🎉 لا توجد بلاغات</h3></div>
      ) : (
        <div className={s.tableCard}>
          <div className={s.tableWrap}>
            <table className={s.table}>
              <thead><tr>
                <th>المُبلّغ</th><th>الإعلان</th><th>السبب</th><th>التفاصيل</th>
                <th>الحالة</th><th>الإجراء</th><th>التاريخ</th><th>إجراءات</th>
              </tr></thead>
              <tbody>
                {reports.map(r => (
                  <tr key={r.id} style={r.status === 'pending' ? { background: 'rgba(239,68,68,0.03)' } : undefined}>
                    <td>
                      <div className={s.userCell}>
                        <div className={s.avatar}>{r.reporter?.name?.[0] || '?'}</div>
                        <span>{r.reporter?.name || 'مجهول'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        {r.ad?.primary_image && <img src={r.ad.primary_image} alt="" className={s.thumbnail} style={{ width: 36, height: 36 }} />}
                        <span style={{ color: 'var(--admin-text)', fontWeight: 600 }}>{r.ad?.title || '—'}</span>
                      </div>
                    </td>
                    <td><span className={`${s.badge} ${s.yellow}`}>{REASON_LABELS[r.reason] || r.reason}</span></td>
                    <td style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {r.description || '—'}
                    </td>
                    <td>
                      <span className={`${s.badge} ${r.status === 'pending' ? s.red : r.status === 'resolved' ? s.green : s.gray}`}>
                        {r.status_label}
                      </span>
                    </td>
                    <td>{r.admin_action_label || '—'}</td>
                    <td style={{ fontSize: 12, color: 'var(--admin-text-muted)', whiteSpace: 'nowrap' }}>{fmtDate(r.created_at)}</td>
                    <td>
                      {r.status === 'pending' ? (
                        <div style={{ display: 'flex', gap: 4 }}>
                          <button className={`${s.btn} ${s.primary} ${s.sm}`} onClick={() => setResolveModal(r)}>معالجة</button>
                          <button className={`${s.btn} ${s.sm}`} onClick={() => handleDismiss(r)} disabled={busy}>رفض</button>
                        </div>
                      ) : (
                        <span style={{ fontSize: 12, color: 'var(--admin-text-muted)' }}>
                          {r.admin?.name || '—'}
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className={s.pagination}>
            <span className={s.paginationInfo}>{meta.total} بلاغ</span>
            <div className={s.paginationBtns}>
              <button className={s.pageBtn} disabled={meta.current_page <= 1} onClick={() => load(meta.current_page - 1)}>السابق</button>
              <button className={s.pageBtn} disabled={meta.current_page >= meta.last_page} onClick={() => load(meta.current_page + 1)}>التالي</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
