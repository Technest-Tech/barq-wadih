'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import {
  fetchPaymentProofs,
  approvePaymentProof,
  rejectPaymentProof,
  type PaymentProofItem,
  type PaymentProofFilters,
  type PaginatedPaymentProofs,
} from '@/lib/api/admin-payment-proofs';
import styles from './payment-proofs.module.css';

function formatCurrency(n: number): string {
  return `${n.toLocaleString('ar-SA', { maximumFractionDigits: 2 })} ر.س`;
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('ar-SA', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

const STATUS_OPTIONS = [
  { value: 'under_review', label: 'قيد المراجعة' },
  { value: 'paid', label: 'مُعتمد' },
  { value: 'failed', label: 'مرفوض' },
  { value: 'all', label: 'الكل' },
];

function statusBadge(status: string): { cls: string; label: string } {
  switch (status) {
    case 'paid':
      return { cls: styles.badgePaid, label: 'مُعتمد' };
    case 'failed':
      return { cls: styles.badgeFailed, label: 'مرفوض' };
    default:
      return { cls: styles.badgeReview, label: 'قيد المراجعة' };
  }
}

export default function AdminPaymentProofsPage() {
  const [data, setData] = useState<PaginatedPaymentProofs | null>(null);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<PaymentProofFilters>({ status: 'under_review' });
  const [page, setPage] = useState(1);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [lightbox, setLightbox] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      setData(await fetchPaymentProofs({ ...filters, page, per_page: 20 }));
    } catch {
      // silent — data stays as-is
    } finally {
      setLoading(false);
    }
  }, [filters, page]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleFilterChange = (key: keyof PaymentProofFilters, value: string) => {
    setFilters((prev) => ({ ...prev, [key]: value || undefined }));
    setPage(1);
  };

  const handleApprove = async (id: number) => {
    if (!confirm('اعتماد تحويل العمولة؟')) return;
    setBusyId(id);
    try {
      await approvePaymentProof(id);
      await loadData();
    } catch {
      alert('فشل اعتماد التحويل');
    } finally {
      setBusyId(null);
    }
  };

  const handleReject = async (id: number) => {
    const reason = prompt('سبب رفض الإيصال (سيظهر للبائع):');
    if (!reason || !reason.trim()) return;
    setBusyId(id);
    try {
      await rejectPaymentProof(id, reason.trim());
      await loadData();
    } catch {
      alert('فشل رفض التحويل');
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className={styles.page}>
      <h1 className={styles.title}>🏦 مراجعة التحويلات البنكية</h1>

      <div className={styles.toolbar}>
        <input
          type="text"
          className={styles.searchInput}
          placeholder="🔍 بحث بالاسم، الهاتف، أو رقم الإعلان..."
          value={filters.q || ''}
          onChange={(e) => handleFilterChange('q', e.target.value)}
        />
        <select
          className={styles.filterSelect}
          value={filters.status || 'under_review'}
          onChange={(e) => handleFilterChange('status', e.target.value)}
        >
          {STATUS_OPTIONS.map((s) => (
            <option key={s.value} value={s.value}>
              {s.label}
            </option>
          ))}
        </select>
      </div>

      {loading ? (
        <div className={styles.loading}>
          <div className={styles.spinner} />
          <span>جاري التحميل...</span>
        </div>
      ) : !data || data.data.length === 0 ? (
        <div className={styles.empty}>
          <span className={styles.emptyIcon}>📭</span>
          لا توجد تحويلات في هذه الحالة
        </div>
      ) : (
        <>
          <div className={styles.grid}>
            {data.data.map((p: PaymentProofItem) => {
              const badge = statusBadge(p.payment_status);
              return (
                <div
                  key={p.id}
                  className={styles.card}
                  style={{ opacity: busyId === p.id ? 0.5 : 1 }}
                >
                  <div className={styles.cardHead}>
                    <div className={styles.avatar}>{p.user?.name?.[0] || '?'}</div>
                    <div>
                      <div className={styles.userName}>{p.user?.name || 'مجهول'}</div>
                      <div className={styles.userMeta} dir="ltr">
                        {p.user?.phone || p.user?.email || '—'}
                      </div>
                    </div>
                    <span className={styles.amount}>{formatCurrency(p.payment_amount)}</span>
                  </div>

                  <div className={styles.adRow}>
                    إعلان:{' '}
                    <Link href={`/ar/admin/ads/${p.id}`}>
                      #{p.id} — {p.title}
                    </Link>
                    {p.category?.name_ar && <> · {p.category.name_ar}</>}
                    {p.city?.name_ar && <> · {p.city.name_ar}</>}
                  </div>

                  <div className={styles.adRow}>
                    <span className={`${styles.badge} ${badge.cls}`}>{badge.label}</span>
                    <span style={{ marginInlineStart: 8, color: '#94a3b8', fontSize: '0.78rem' }}>
                      رُفع: {formatDate(p.uploaded_at)}
                    </span>
                  </div>

                  {p.payment_proof_url ? (
                    <div className={styles.proof} onClick={() => setLightbox(p.payment_proof_url)}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={p.payment_proof_url} alt="إيصال التحويل" />
                    </div>
                  ) : (
                    <div className={styles.note}>لا يوجد إيصال مرفوع</div>
                  )}

                  {p.payment_review_note && p.payment_status === 'failed' && (
                    <div className={styles.note}>سبب الرفض: {p.payment_review_note}</div>
                  )}

                  {p.payment_status !== 'paid' && (
                    <div className={styles.actions}>
                      <button
                        className={`${styles.btn} ${styles.approve}`}
                        disabled={busyId === p.id || !p.payment_proof_url}
                        onClick={() => handleApprove(p.id)}
                      >
                        ✓ اعتماد العمولة
                      </button>
                      <button
                        className={`${styles.btn} ${styles.reject}`}
                        disabled={busyId === p.id}
                        onClick={() => handleReject(p.id)}
                      >
                        ✕ رفض
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {data.pagination.last_page > 1 && (
            <div className={styles.pagination}>
              <button
                className={styles.pageBtn}
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                ← السابق
              </button>
              <span className={styles.pageInfo}>
                {page} / {data.pagination.last_page} — {data.pagination.total} تحويل
              </span>
              <button
                className={styles.pageBtn}
                disabled={page >= data.pagination.last_page}
                onClick={() => setPage((p) => p + 1)}
              >
                التالي →
              </button>
            </div>
          )}
        </>
      )}

      {lightbox && (
        <div className={styles.lightbox} onClick={() => setLightbox(null)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightbox} alt="إيصال التحويل" />
        </div>
      )}
    </div>
  );
}
