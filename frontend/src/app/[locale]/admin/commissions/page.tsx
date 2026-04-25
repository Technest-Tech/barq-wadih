'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import {
  fetchCommissions,
  fetchCommissionSummary,
  updateCommissionStatus,
  type CommissionItem,
  type CommissionSummary,
  type CommissionFilters,
  type PaginatedCommissions,
} from '@/lib/api/admin-commissions';
import ENDPOINTS from '@/lib/api/endpoints';
import styles from './commissions.module.css';

function formatCurrency(n: number): string {
  return `${n.toLocaleString('ar-SA', { maximumFractionDigits: 2 })} ر.س`;
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('ar-SA', {
    year: 'numeric', month: 'short', day: 'numeric',
  });
}

const STATUS_OPTIONS = [
  { value: 'paid', label: 'مدفوع' },
  { value: 'pending', label: 'معلّق' },
  { value: 'not_applicable', label: 'لا ينطبق' },
];

export default function AdminCommissionsPage() {
  const [data, setData] = useState<PaginatedCommissions | null>(null);
  const [summary, setSummary] = useState<CommissionSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<CommissionFilters>({});
  const [page, setPage] = useState(1);
  const [statusMenuOpen, setStatusMenuOpen] = useState<number | null>(null);
  const [updatingId, setUpdatingId] = useState<number | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [commissions, summaryData] = await Promise.all([
        fetchCommissions({ ...filters, page, per_page: 20 }),
        fetchCommissionSummary(),
      ]);
      setData(commissions);
      setSummary(summaryData);
    } catch {
      // Error handled silently — data stays null
    } finally {
      setLoading(false);
    }
  }, [filters, page]);

  useEffect(() => { loadData(); }, [loadData]);

  const handleFilterChange = (key: keyof CommissionFilters, value: string) => {
    setFilters(prev => ({ ...prev, [key]: value || undefined }));
    setPage(1);
  };

  const clearFilters = () => {
    setFilters({});
    setPage(1);
  };

  const handleStatusChange = async (id: number, newStatus: string) => {
    setUpdatingId(id);
    setStatusMenuOpen(null);
    try {
      await updateCommissionStatus(id, newStatus);
      await loadData();
    } catch {
      alert('فشل تحديث الحالة');
    } finally {
      setUpdatingId(null);
    }
  };

  const handleExport = () => {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== '') params.append(key, String(value));
    });
    const qs = params.toString();
    // Direct API call with auth — open in new tab
    const token = typeof window !== 'undefined' ? localStorage.getItem('auth_token') : null;
    const apiBase = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000/api';
    const url = `${apiBase}${ENDPOINTS.ADMIN_COMMISSIONS_EXPORT}${qs ? `?${qs}` : ''}${qs ? '&' : '?'}token=${token}`;
    window.open(url, '_blank');
  };

  // ── Render ──────────────────────────────────────────────────────────────

  return (
    <div className={styles.page}>
      <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', marginBottom: '1.5rem' }}>
        💰 إدارة العمولات
      </h1>

      {/* ── Summary KPIs ──────────────────────────────────────────────── */}
      {summary && (
        <div className={styles.summaryGrid}>
          <div className={`${styles.summaryCard} ${styles.paid}`}>
            <span className={styles.icon}>✅</span>
            <span className={styles.value}>{formatCurrency(summary.total_paid)}</span>
            <span className={styles.label}>إجمالي المدفوع</span>
          </div>
          <div className={`${styles.summaryCard} ${styles.pending}`}>
            <span className={styles.icon}>⏳</span>
            <span className={styles.value}>{formatCurrency(summary.total_pending)}</span>
            <span className={styles.label}>عمولات معلقة</span>
          </div>
          <div className={`${styles.summaryCard} ${styles.month}`}>
            <span className={styles.icon}>📅</span>
            <span className={styles.value}>{formatCurrency(summary.this_month)}</span>
            <span className={styles.label}>هذا الشهر</span>
          </div>
          <div className={`${styles.summaryCard} ${styles.count}`}>
            <span className={styles.icon}>📊</span>
            <span className={styles.value}>{summary.total_count.toLocaleString('ar-SA')}</span>
            <span className={styles.label}>إجمالي العمولات</span>
          </div>
        </div>
      )}

      {/* ── Toolbar ───────────────────────────────────────────────────── */}
      <div className={styles.toolbar}>
        <input
          type="text"
          className={styles.searchInput}
          placeholder="🔍 بحث بالاسم أو الهاتف..."
          value={filters.q || ''}
          onChange={e => handleFilterChange('q', e.target.value)}
        />
        <select
          className={styles.filterSelect}
          value={filters.status || ''}
          onChange={e => handleFilterChange('status', e.target.value)}
        >
          <option value="">كل الحالات</option>
          {STATUS_OPTIONS.map(s => (
            <option key={s.value} value={s.value}>{s.label}</option>
          ))}
        </select>
        <input
          type="date"
          className={styles.dateInput}
          value={filters.from || ''}
          onChange={e => handleFilterChange('from', e.target.value)}
          title="من تاريخ"
        />
        <input
          type="date"
          className={styles.dateInput}
          value={filters.to || ''}
          onChange={e => handleFilterChange('to', e.target.value)}
          title="إلى تاريخ"
        />
        <button className={styles.exportBtn} onClick={handleExport}>
          📥 تصدير CSV
        </button>
        {Object.keys(filters).length > 0 && (
          <button className={styles.clearBtn} onClick={clearFilters}>
            ✕ مسح الفلاتر
          </button>
        )}
      </div>

      {/* ── Table ─────────────────────────────────────────────────────── */}
      {loading ? (
        <div className={styles.loading}>
          <div className={styles.loadingSpinner} />
          <span>جاري التحميل...</span>
        </div>
      ) : !data || data.data.length === 0 ? (
        <div className={styles.empty}>
          <span className={styles.emptyIcon}>💸</span>
          لا توجد عمولات حالياً
        </div>
      ) : (
        <>
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>#</th>
                  <th>المستخدم</th>
                  <th>الإعلان</th>
                  <th>سعر البيع</th>
                  <th>مبلغ العمولة</th>
                  <th>الحالة</th>
                  <th>تاريخ الدفع</th>
                  <th>التاريخ</th>
                </tr>
              </thead>
              <tbody>
                {data.data.map((c: CommissionItem) => (
                  <tr key={c.id} style={{ opacity: updatingId === c.id ? 0.5 : 1 }}>
                    <td>
                      <Link href={`/ar/admin/commissions/${c.id}`} style={{ color: '#a5b4fc', textDecoration: 'none' }}>
                        #{c.id}
                      </Link>
                    </td>
                    <td>
                      <div className={styles.userCell}>
                        <div className={styles.userAvatar}>
                          {c.user?.name?.[0] || '?'}
                        </div>
                        <span className={styles.userName}>{c.user?.name || 'مجهول'}</span>
                      </div>
                    </td>
                    <td className={styles.adTitle}>{c.ad?.title || '—'}</td>
                    <td className={styles.priceCell}>{formatCurrency(c.sale_price)}</td>
                    <td style={{ fontWeight: 700 }}>{formatCurrency(c.commission_amount)}</td>
                    <td>
                      <div className={styles.statusDropdown}>
                        <span
                          className={`${styles.statusBadge} ${styles[`status${c.status.charAt(0).toUpperCase() + c.status.slice(1)}`] || ''}`}
                          onClick={() => setStatusMenuOpen(statusMenuOpen === c.id ? null : c.id)}
                        >
                          {c.status_label}
                          <span style={{ fontSize: '.65rem' }}>▼</span>
                        </span>
                        {statusMenuOpen === c.id && (
                          <div className={styles.statusMenu}>
                            {STATUS_OPTIONS.map(opt => (
                              <button
                                key={opt.value}
                                className={styles.statusOption}
                                onClick={() => handleStatusChange(c.id, opt.value)}
                                disabled={opt.value === c.status}
                              >
                                {opt.label}
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    </td>
                    <td>{c.paid_at ? formatDate(c.paid_at) : '—'}</td>
                    <td style={{ color: '#94a3b8', fontSize: '.82rem' }}>{formatDate(c.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* ── Pagination ──────────────────────────────────────────── */}
          {data.pagination.last_page > 1 && (
            <div className={styles.pagination}>
              <button
                className={styles.pageBtn}
                disabled={page <= 1}
                onClick={() => setPage(p => p - 1)}
              >
                ← السابق
              </button>
              <span className={styles.pageInfo}>
                {page} / {data.pagination.last_page} — {data.pagination.total} عمولة
              </span>
              <button
                className={styles.pageBtn}
                disabled={page >= data.pagination.last_page}
                onClick={() => setPage(p => p + 1)}
              >
                التالي →
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
