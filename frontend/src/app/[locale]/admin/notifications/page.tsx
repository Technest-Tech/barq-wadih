'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  fetchCampaigns, fetchNotificationStats, createCampaign, sendCampaign, deleteCampaign,
  type CampaignItem, type NotificationStats, type PaginatedCampaigns, type CampaignCreateData,
} from '@/lib/api/admin-notifications';
import styles from './notifications.module.css';

const STATUS_TABS = [
  { key: '', label: 'الكل' },
  { key: 'draft', label: 'مسودة' },
  { key: 'scheduled', label: 'مجدولة' },
  { key: 'sent', label: 'تم الإرسال' },
  { key: 'failed', label: 'فشل' },
];

const statusClass: Record<string, string> = {
  draft: styles.badgeDraft, scheduled: styles.badgeScheduled, sent: styles.badgeSent, failed: styles.badgeFailed,
};

function formatDate(d: string): string {
  return new Date(d).toLocaleDateString('ar-SA', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export default function AdminNotificationsPage() {
  const [data, setData] = useState<PaginatedCampaigns | null>(null);
  const [stats, setStats] = useState<NotificationStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);
  const [showModal, setShowModal] = useState(false);
  const [saving, setSaving] = useState(false);

  // Form state
  const [form, setForm] = useState<CampaignCreateData>({
    title_ar: '', body_ar: '', target_type: 'all',
  });

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [campaigns, statsData] = await Promise.all([
        fetchCampaigns({ status: statusFilter || undefined, page }),
        fetchNotificationStats(),
      ]);
      setData(campaigns);
      setStats(statsData);
    } catch { /* silent */ } finally { setLoading(false); }
  }, [statusFilter, page]);

  useEffect(() => { loadData(); }, [loadData]);

  const handleCreate = async () => {
    if (!form.title_ar || !form.body_ar) return;
    setSaving(true);
    try {
      await createCampaign(form);
      setShowModal(false);
      setForm({ title_ar: '', body_ar: '', target_type: 'all' });
      await loadData();
    } catch { alert('فشل إنشاء الحملة'); } finally { setSaving(false); }
  };

  const handleSend = async (id: number) => {
    if (!confirm('هل تريد إرسال هذه الحملة الآن؟')) return;
    try {
      await sendCampaign(id);
      await loadData();
    } catch { alert('فشل إرسال الحملة'); }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('هل تريد حذف هذه المسودة؟')) return;
    try {
      await deleteCampaign(id);
      await loadData();
    } catch { alert('فشل حذف الحملة'); }
  };

  return (
    <div className={styles.page}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', margin: 0 }}>🔔 حملات الإشعارات</h1>
        <button className={styles.createBtn} onClick={() => setShowModal(true)}>+ حملة جديدة</button>
      </div>

      {/* Summary */}
      {stats && (
        <div className={styles.summaryGrid}>
          <div className={styles.summaryCard}><div className={styles.summaryValue}>{stats.total_campaigns}</div><div className={styles.summaryLabel}>إجمالي الحملات</div></div>
          <div className={styles.summaryCard}><div className={styles.summaryValue}>{stats.sent_campaigns}</div><div className={styles.summaryLabel}>تم إرسالها</div></div>
          <div className={styles.summaryCard}><div className={styles.summaryValue}>{stats.draft_campaigns}</div><div className={styles.summaryLabel}>مسودات</div></div>
          <div className={styles.summaryCard}><div className={styles.summaryValue}>{stats.total_recipients.toLocaleString('ar-SA')}</div><div className={styles.summaryLabel}>مستلمون</div></div>
        </div>
      )}

      {/* Tabs */}
      <div className={styles.tabBar}>
        {STATUS_TABS.map(t => (
          <button key={t.key} className={`${styles.tab} ${statusFilter === t.key ? styles.tabActive : ''}`} onClick={() => { setStatusFilter(t.key); setPage(1); }}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Table */}
      {loading ? (
        <div className={styles.loading}><div className={styles.loadingSpinner} /><span>جاري التحميل...</span></div>
      ) : !data || data.data.length === 0 ? (
        <div className={styles.empty}><span style={{ fontSize: '3rem', display: 'block', marginBottom: '1rem' }}>🔕</span>لا توجد حملات</div>
      ) : (
        <>
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead><tr><th>#</th><th>العنوان</th><th>الهدف</th><th>الحالة</th><th>المستلمون</th><th>التاريخ</th><th>الإجراءات</th></tr></thead>
              <tbody>
                {data.data.map((c: CampaignItem) => (
                  <tr key={c.id}>
                    <td>{c.id}</td>
                    <td style={{ fontWeight: 600 }}>{c.title_ar}</td>
                    <td><span className={styles.targetBadge}>{c.target_type_label}</span></td>
                    <td><span className={`${styles.badge} ${statusClass[c.status] || ''}`}>{c.status_label}</span></td>
                    <td>{c.recipients_count.toLocaleString('ar-SA')}</td>
                    <td style={{ fontSize: '.82rem', color: '#94a3b8' }}>{c.sent_at ? formatDate(c.sent_at) : c.scheduled_at ? `مجدولة: ${formatDate(c.scheduled_at)}` : formatDate(c.created_at)}</td>
                    <td>
                      {c.status === 'draft' && (
                        <>
                          <button className={`${styles.actionBtn} ${styles.sendBtn}`} onClick={() => handleSend(c.id)}>إرسال</button>
                          <button className={`${styles.actionBtn} ${styles.deleteBtn}`} onClick={() => handleDelete(c.id)}>حذف</button>
                        </>
                      )}
                      {c.status === 'scheduled' && (
                        <button className={`${styles.actionBtn} ${styles.sendBtn}`} onClick={() => handleSend(c.id)}>إرسال الآن</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {data.pagination.last_page > 1 && (
            <div className={styles.pagination}>
              <button className={styles.pageBtn} disabled={page <= 1} onClick={() => setPage(p => p - 1)}>← السابق</button>
              <span className={styles.pageInfo}>{page} / {data.pagination.last_page}</span>
              <button className={styles.pageBtn} disabled={page >= data.pagination.last_page} onClick={() => setPage(p => p + 1)}>التالي →</button>
            </div>
          )}
        </>
      )}

      {/* Create Modal */}
      {showModal && (
        <div className={styles.modalOverlay} onClick={() => setShowModal(false)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <h2 className={styles.modalTitle}>📝 إنشاء حملة جديدة</h2>

            <div className={styles.formGroup}>
              <label className={styles.formLabel}>العنوان (عربي) *</label>
              <input className={styles.formInput} value={form.title_ar} onChange={e => setForm(f => ({ ...f, title_ar: e.target.value }))} placeholder="عنوان الإشعار..." />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>العنوان (إنجليزي)</label>
              <input className={styles.formInput} value={form.title_en || ''} onChange={e => setForm(f => ({ ...f, title_en: e.target.value }))} placeholder="Notification title..." dir="ltr" />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>المحتوى (عربي) *</label>
              <textarea className={styles.formTextarea} value={form.body_ar} onChange={e => setForm(f => ({ ...f, body_ar: e.target.value }))} placeholder="نص الإشعار..." />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>المحتوى (إنجليزي)</label>
              <textarea className={styles.formTextarea} value={form.body_en || ''} onChange={e => setForm(f => ({ ...f, body_en: e.target.value }))} placeholder="Notification body..." dir="ltr" />
            </div>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>الجمهور المستهدف</label>
              <div className={styles.radioGroup}>
                {[{ v: 'all', l: 'الجميع' }, { v: 'city', l: 'مدينة' }, { v: 'category', l: 'قسم' }, { v: 'specific_users', l: 'مستخدمون' }].map(o => (
                  <label key={o.v} className={styles.radioLabel}>
                    <input type="radio" name="target" checked={form.target_type === o.v} onChange={() => setForm(f => ({ ...f, target_type: o.v }))} />
                    {o.l}
                  </label>
                ))}
              </div>
            </div>
            {form.target_type === 'city' && (
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>معرّف المدينة</label>
                <input className={styles.formInput} type="number" value={form.target_city_id || ''} onChange={e => setForm(f => ({ ...f, target_city_id: parseInt(e.target.value) || undefined }))} placeholder="مثال: 5" />
              </div>
            )}
            {form.target_type === 'category' && (
              <div className={styles.formGroup}>
                <label className={styles.formLabel}>معرّف القسم</label>
                <input className={styles.formInput} type="number" value={form.target_category_id || ''} onChange={e => setForm(f => ({ ...f, target_category_id: parseInt(e.target.value) || undefined }))} placeholder="مثال: 3" />
              </div>
            )}
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>جدولة (اختياري)</label>
              <input className={styles.formInput} type="datetime-local" value={form.scheduled_at || ''} onChange={e => setForm(f => ({ ...f, scheduled_at: e.target.value || undefined }))} />
            </div>

            <div className={styles.modalActions}>
              <button className={styles.cancelBtn} onClick={() => setShowModal(false)}>إلغاء</button>
              <button className={styles.submitBtn} disabled={saving || !form.title_ar || !form.body_ar} onClick={handleCreate}>
                {saving ? 'جاري الحفظ...' : form.scheduled_at ? 'جدولة' : 'حفظ كمسودة'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
