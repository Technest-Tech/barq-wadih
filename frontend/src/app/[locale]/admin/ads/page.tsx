'use client';
import { useEffect, useState, useCallback } from 'react';
import { fetchAdminAds, approveAd, rejectAd, deleteAd, restoreAd, type AdminAd, type AdminAdFilters } from '@/lib/api/admin';
import s from '../admin-shared.module.css';

const STATUS_MAP: Record<string, { label: string; cls: string }> = {
  active: { label: 'نشط', cls: 'green' }, sold: { label: 'مُباع', cls: 'blue' },
  expired: { label: 'منتهي', cls: 'gray' }, pending_review: { label: 'قيد المراجعة', cls: 'yellow' },
  rejected: { label: 'مرفوض', cls: 'red' }, deleted: { label: 'محذوف', cls: 'red' },
};
const MOD_MAP: Record<string, { label: string; cls: string }> = {
  approved: { label: 'مقبول', cls: 'green' }, flagged: { label: 'مُبلّغ', cls: 'yellow' },
  under_review: { label: 'قيد المراجعة', cls: 'yellow' }, rejected: { label: 'مرفوض', cls: 'red' },
};

export default function AdminAdsPage() {
  const [ads, setAds] = useState<AdminAd[]>([]);
  const [meta, setMeta] = useState({ current_page: 1, last_page: 1, per_page: 20, total: 0 });
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<AdminAdFilters>({ sort: 'created_at', dir: 'desc' });
  const [search, setSearch] = useState('');
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [modal, setModal] = useState<{ type: 'reject' | 'delete'; ad: AdminAd } | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState<number | null>(null);

  const showToast = (msg: string, type: 'success' | 'error') => { setToast({ msg, type }); setTimeout(() => setToast(null), 3000); };

  const load = useCallback(async (f?: AdminAdFilters) => {
    setLoading(true);
    try {
      const r = await fetchAdminAds(f || filters);
      setAds(r.data); setMeta(r.meta);
    } catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setLoading(false); }
  }, [filters]);

  useEffect(() => { load(); }, [load]);

  const applyFilter = (key: keyof AdminAdFilters, val: string) => {
    const nf = { ...filters, [key]: val || undefined, page: 1 };
    setFilters(nf); load(nf);
  };

  const handleApprove = async (ad: AdminAd) => {
    setBusy(ad.id);
    try { await approveAd(ad.id); showToast('تم قبول الإعلان', 'success'); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(null); }
  };

  const handleReject = async () => {
    if (!modal || modal.type !== 'reject' || !reason.trim()) return;
    setBusy(modal.ad.id);
    try { await rejectAd(modal.ad.id, reason); showToast('تم رفض الإعلان', 'success'); setModal(null); setReason(''); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(null); }
  };

  const handleDelete = async () => {
    if (!modal || modal.type !== 'delete') return;
    setBusy(modal.ad.id);
    try { await deleteAd(modal.ad.id, reason); showToast('تم حذف الإعلان', 'success'); setModal(null); setReason(''); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(null); }
  };

  const handleRestore = async (ad: AdminAd) => {
    setBusy(ad.id);
    try { await restoreAd(ad.id); showToast('تم استعادة الإعلان', 'success'); load(); }
    catch (e) { showToast(e instanceof Error ? e.message : 'خطأ', 'error'); }
    finally { setBusy(null); }
  };

  const fmtDate = (d: string) => new Date(d).toLocaleDateString('ar-SA', { month: 'short', day: 'numeric', year: 'numeric' });

  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {/* Reject/Delete Modal */}
      {modal && (
        <div className={s.modalOverlay} onClick={() => { setModal(null); setReason(''); }}>
          <div className={s.modal} onClick={e => e.stopPropagation()}>
            <h3 className={s.modalTitle}>{modal.type === 'reject' ? '❌ رفض الإعلان' : '🗑️ حذف الإعلان'}</h3>
            <p className={s.modalBody}>الإعلان: &quot;{modal.ad.title}&quot;</p>
            <div className={s.modalField}>
              <label className={s.modalLabel}>{modal.type === 'reject' ? 'سبب الرفض *' : 'ملاحظة (اختياري)'}</label>
              <textarea className={s.modalTextarea} value={reason} onChange={e => setReason(e.target.value)}
                placeholder={modal.type === 'reject' ? 'اكتب سبب الرفض...' : 'ملاحظة إدارية...'} />
            </div>
            <div className={s.modalActions}>
              <button className={`${s.btn} ${s.danger}`} onClick={modal.type === 'reject' ? handleReject : handleDelete}
                disabled={modal.type === 'reject' && !reason.trim()}>تأكيد</button>
              <button className={s.btn} onClick={() => { setModal(null); setReason(''); }}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className={s.pageHeader}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <h1 className={s.pageTitle}>إدارة الإعلانات</h1>
          <span className={s.totalBadge}>{meta.total} إعلان</span>
        </div>
      </div>

      {/* Filters */}
      <div className={s.filterBar}>
        <div className={s.filterRow}>
          <input className={s.searchInput} placeholder="🔍 بحث بالعنوان أو الرقم..." value={search}
            onChange={e => setSearch(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') applyFilter('q', search); }} />
          <select className={s.select} value={filters.status || ''} onChange={e => applyFilter('status', e.target.value)}>
            <option value="">كل الحالات</option>
            <option value="active">نشط</option><option value="pending_review">قيد المراجعة</option>
            <option value="sold">مُباع</option><option value="expired">منتهي</option>
            <option value="rejected">مرفوض</option>
          </select>
          <select className={s.select} value={filters.moderation_status || ''} onChange={e => applyFilter('moderation_status', e.target.value)}>
            <option value="">كل حالات المراجعة</option>
            <option value="approved">مقبول</option><option value="flagged">مُبلّغ</option>
            <option value="under_review">قيد المراجعة</option><option value="rejected">مرفوض</option>
          </select>
        </div>
        <div className={s.filterRow}>
          <button className={`${s.chip} ${filters.has_reports === '1' ? s.active : ''}`}
            onClick={() => applyFilter('has_reports', filters.has_reports === '1' ? '' : '1')}>⚠️ يحتوي بلاغات</button>
          <input type="date" className={s.select} value={filters.date_from || ''} onChange={e => applyFilter('date_from', e.target.value)} />
          <input type="date" className={s.select} value={filters.date_to || ''} onChange={e => applyFilter('date_to', e.target.value)} />
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className={s.loading}><div className={s.spinner} /><span>جاري التحميل...</span></div>
      ) : ads.length === 0 ? (
        <div className={s.empty}><h3>لا توجد نتائج</h3></div>
      ) : (
        <div className={s.tableCard}>
          <div className={s.tableWrap}>
            <table className={s.table}>
              <thead><tr>
                <th>الصورة</th><th>العنوان</th><th>المُعلن</th><th>التصنيف</th><th>السعر</th>
                <th>الحالة</th><th>المراجعة</th><th>البلاغات</th><th>التاريخ</th><th>إجراءات</th>
              </tr></thead>
              <tbody>
                {ads.map(ad => (
                  <tr key={ad.id}>
                    <td>
                      {ad.images?.[0]?.url ? <img src={ad.images[0].url} alt="" className={s.thumbnail} /> : <div className={s.thumbnail} style={{ background: 'var(--admin-surface)' }} />}
                    </td>
                    <td style={{ color: 'var(--admin-text)', fontWeight: 600, maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {ad.title}
                    </td>
                    <td>
                      <div className={s.userCell}>
                        <div className={s.avatar}>{ad.user?.name?.[0] || '?'}</div>
                        <span>{ad.user?.name || 'مجهول'}</span>
                      </div>
                    </td>
                    <td>{ad.category?.name_ar || '—'}</td>
                    <td style={{ fontWeight: 700, direction: 'ltr' }}>{ad.price > 0 ? `${ad.price.toLocaleString()} ر.س` : 'مجاني'}</td>
                    <td><span className={`${s.badge} ${s[STATUS_MAP[ad.status]?.cls || 'gray']}`}>{STATUS_MAP[ad.status]?.label || ad.status}</span></td>
                    <td><span className={`${s.badge} ${s[MOD_MAP[ad.moderation_status]?.cls || 'gray']}`}>{MOD_MAP[ad.moderation_status]?.label || ad.moderation_status}</span></td>
                    <td style={{ textAlign: 'center' }}>{ad.reports_count > 0 ? <span className={`${s.badge} ${s.red}`}>{ad.reports_count}</span> : '—'}</td>
                    <td style={{ fontSize: 12, color: 'var(--admin-text-muted)', whiteSpace: 'nowrap' }}>{fmtDate(ad.created_at)}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 4 }}>
                        {ad.moderation_status !== 'approved' && !ad.deleted_at && (
                          <button className={`${s.btn} ${s.success} ${s.sm}`} onClick={() => handleApprove(ad)} disabled={busy === ad.id}>✅</button>
                        )}
                        {!ad.deleted_at && (
                          <button className={`${s.btn} ${s.warning} ${s.sm}`} onClick={() => setModal({ type: 'reject', ad })} disabled={busy === ad.id}>❌</button>
                        )}
                        {!ad.deleted_at ? (
                          <button className={`${s.btn} ${s.danger} ${s.sm}`} onClick={() => setModal({ type: 'delete', ad })} disabled={busy === ad.id}>🗑️</button>
                        ) : (
                          <button className={`${s.btn} ${s.success} ${s.sm}`} onClick={() => handleRestore(ad)} disabled={busy === ad.id}>♻️</button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className={s.pagination}>
            <span className={s.paginationInfo}>عرض {(meta.current_page - 1) * meta.per_page + 1} - {Math.min(meta.current_page * meta.per_page, meta.total)} من {meta.total}</span>
            <div className={s.paginationBtns}>
              <button className={s.pageBtn} disabled={meta.current_page <= 1} onClick={() => { const nf = { ...filters, page: meta.current_page - 1 }; setFilters(nf); load(nf); }}>السابق</button>
              <button className={s.pageBtn} disabled={meta.current_page >= meta.last_page} onClick={() => { const nf = { ...filters, page: meta.current_page + 1 }; setFilters(nf); load(nf); }}>التالي</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
