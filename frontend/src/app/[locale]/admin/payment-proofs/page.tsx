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

type TabKey = 'under_review' | 'paid' | 'failed' | 'all';

const TABS: { value: TabKey; label: string }[] = [
  { value: 'under_review', label: 'قيد المراجعة' },
  { value: 'paid', label: 'مُعتمدة' },
  { value: 'failed', label: 'مرفوضة' },
  { value: 'all', label: 'الكل' },
];

function statusChip(status: string): { cls: string; label: string } {
  switch (status) {
    case 'paid':
      return { cls: styles.chipPaid, label: 'مُعتمدة' };
    case 'failed':
      return { cls: styles.chipFailed, label: 'مرفوضة' };
    default:
      return { cls: styles.chipReview, label: 'قيد المراجعة' };
  }
}

type Kpis = { review: number; paid: number; failed: number; pendingAmount: number };
type ModalState = { type: 'approve' | 'reject'; item: PaymentProofItem } | null;
type Toast = { kind: 'ok' | 'err'; msg: string } | null;

export default function AdminPaymentProofsPage() {
  const [data, setData] = useState<PaginatedPaymentProofs | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [filters, setFilters] = useState<PaymentProofFilters>({ status: 'under_review' });
  const [page, setPage] = useState(1);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [lightbox, setLightbox] = useState<string | null>(null);
  const [kpis, setKpis] = useState<Kpis | null>(null);
  const [modal, setModal] = useState<ModalState>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [modalBusy, setModalBusy] = useState(false);
  const [toast, setToast] = useState<Toast>(null);

  const showToast = (kind: 'ok' | 'err', msg: string) => {
    setToast({ kind, msg });
    setTimeout(() => setToast(null), 2600);
  };

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      setData(await fetchPaymentProofs({ ...filters, page, per_page: 20 }));
    } catch {
      showToast('err', 'تعذّر تحميل التحويلات');
    } finally {
      setLoading(false);
    }
  }, [filters, page]);

  const loadKpis = useCallback(async () => {
    try {
      const [review, paid, failed] = await Promise.all([
        fetchPaymentProofs({ status: 'under_review', per_page: 100 }),
        fetchPaymentProofs({ status: 'paid', per_page: 1 }),
        fetchPaymentProofs({ status: 'failed', per_page: 1 }),
      ]);
      setKpis({
        review: review.pagination.total,
        paid: paid.pagination.total,
        failed: failed.pagination.total,
        pendingAmount: review.data.reduce((s, r) => s + (r.payment_amount || 0), 0),
      });
    } catch {
      /* KPIs are non-critical */
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  useEffect(() => {
    loadKpis();
  }, [loadKpis]);

  const refresh = async () => {
    setRefreshing(true);
    await Promise.all([loadData(), loadKpis()]);
    setRefreshing(false);
  };

  const handleSearch = (q: string) => {
    setFilters((prev) => ({ ...prev, q: q || undefined }));
    setPage(1);
  };

  const setTab = (status: TabKey) => {
    setFilters((prev) => ({ ...prev, status }));
    setPage(1);
  };

  const confirmApprove = async () => {
    if (!modal) return;
    const id = modal.item.id;
    setModalBusy(true);
    setBusyId(id);
    try {
      await approvePaymentProof(id);
      setModal(null);
      await Promise.all([loadData(), loadKpis()]);
      showToast('ok', 'تم اعتماد التحويل بنجاح');
    } catch {
      showToast('err', 'فشل اعتماد التحويل');
    } finally {
      setModalBusy(false);
      setBusyId(null);
    }
  };

  const confirmReject = async () => {
    if (!modal || !rejectReason.trim()) return;
    const id = modal.item.id;
    setModalBusy(true);
    setBusyId(id);
    try {
      await rejectPaymentProof(id, rejectReason.trim());
      setModal(null);
      setRejectReason('');
      await Promise.all([loadData(), loadKpis()]);
      showToast('ok', 'تم رفض الإيصال');
    } catch {
      showToast('err', 'فشل رفض التحويل');
    } finally {
      setModalBusy(false);
      setBusyId(null);
    }
  };

  const openModal = (type: 'approve' | 'reject', item: PaymentProofItem) => {
    setRejectReason('');
    setModal({ type, item });
  };

  const tabCount = (t: TabKey): number | null => {
    if (!kpis) return null;
    if (t === 'under_review') return kpis.review;
    if (t === 'paid') return kpis.paid;
    if (t === 'failed') return kpis.failed;
    return kpis.review + kpis.paid + kpis.failed;
  };

  return (
    <div className={styles.page}>
      {/* ── Header ── */}
      <div className={styles.header}>
        <div className={styles.titleWrap}>
          <h1 className={styles.title}>
            <span className={styles.titleIcon}>🏦</span>
            مراجعة التحويلات البنكية
          </h1>
          <p className={styles.subtitle}>اعتماد إيصالات تحويل عمولة البيع المرفوعة من البائعين</p>
        </div>
        <button className={styles.refreshBtn} onClick={refresh} disabled={refreshing}>
          <svg
            className={refreshing ? styles.spin : ''}
            width="15"
            height="15"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M23 4v6h-6" />
            <path d="M1 20v-6h6" />
            <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
          </svg>
          تحديث
        </button>
      </div>

      {/* ── KPI row ── */}
      <div className={styles.kpiGrid}>
        <div className={`${styles.kpiCard} ${styles.review}`}>
          <div className={styles.kpiTop}>
            <span className={styles.kpiIcon}>⏳</span>
          </div>
          <div className={styles.kpiValue}>{kpis ? kpis.review.toLocaleString('ar-SA') : '—'}</div>
          <div className={styles.kpiLabel}>قيد المراجعة</div>
        </div>
        <div className={`${styles.kpiCard} ${styles.amount}`}>
          <div className={styles.kpiTop}>
            <span className={styles.kpiIcon}>💰</span>
          </div>
          <div className={styles.kpiValue}>{kpis ? formatCurrency(kpis.pendingAmount) : '—'}</div>
          <div className={styles.kpiLabel}>قيمة بانتظار الاعتماد</div>
        </div>
        <div className={`${styles.kpiCard} ${styles.paid}`}>
          <div className={styles.kpiTop}>
            <span className={styles.kpiIcon}>✅</span>
          </div>
          <div className={styles.kpiValue}>{kpis ? kpis.paid.toLocaleString('ar-SA') : '—'}</div>
          <div className={styles.kpiLabel}>تحويلات مُعتمدة</div>
        </div>
        <div className={`${styles.kpiCard} ${styles.failed}`}>
          <div className={styles.kpiTop}>
            <span className={styles.kpiIcon}>🚫</span>
          </div>
          <div className={styles.kpiValue}>{kpis ? kpis.failed.toLocaleString('ar-SA') : '—'}</div>
          <div className={styles.kpiLabel}>تحويلات مرفوضة</div>
        </div>
      </div>

      {/* ── Toolbar ── */}
      <div className={styles.toolbar}>
        <div className={styles.searchWrap}>
          <span className={styles.searchIcon}>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
          </span>
          <input
            type="text"
            className={styles.search}
            placeholder="بحث بالاسم، الهاتف، أو رقم الإعلان..."
            value={filters.q || ''}
            onChange={(e) => handleSearch(e.target.value)}
          />
        </div>
        <div className={styles.tabs}>
          {TABS.map((t) => {
            const count = tabCount(t.value);
            const active = (filters.status || 'under_review') === t.value;
            return (
              <button
                key={t.value}
                className={`${styles.tab} ${active ? styles.tabActive : ''}`}
                onClick={() => setTab(t.value)}
              >
                {t.label}
                {count !== null && t.value !== 'all' && (
                  <span className={styles.tabCount}>{count}</span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* ── Content ── */}
      {loading ? (
        <div className={styles.skelGrid}>
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className={styles.skel} />
          ))}
        </div>
      ) : !data || data.data.length === 0 ? (
        <div className={styles.empty}>
          <span className={styles.emptyIcon}>📭</span>
          <span className={styles.emptyTitle}>لا توجد تحويلات في هذه الحالة</span>
          <span>ستظهر هنا إيصالات التحويل فور رفعها من البائعين.</span>
        </div>
      ) : (
        <>
          <div className={styles.grid}>
            {data.data.map((p: PaymentProofItem) => {
              const chip = statusChip(p.payment_status);
              const isPaid = p.payment_status === 'paid';
              return (
                <div
                  key={p.id}
                  className={`${styles.card} ${busyId === p.id ? styles.cardBusy : ''}`}
                >
                  <div className={styles.cardTop}>
                    <div className={styles.avatar}>{p.user?.name?.[0] || '?'}</div>
                    <div className={styles.who}>
                      <div className={styles.name}>{p.user?.name || 'مجهول'}</div>
                      <div className={styles.contact} dir="ltr">
                        {p.user?.phone || p.user?.email || '—'}
                      </div>
                    </div>
                    <div className={styles.amountPill}>
                      {formatCurrency(p.payment_amount)}
                      <small>عمولة البيع</small>
                    </div>
                  </div>

                  <div className={styles.adRow}>
                    <Link href={`/ar/admin/ads/${p.id}`}>
                      #{p.id} — {p.title}
                    </Link>
                    {p.category?.name_ar && (
                      <>
                        <span className={styles.dotSep}>·</span>
                        {p.category.name_ar}
                      </>
                    )}
                    {p.city?.name_ar && (
                      <>
                        <span className={styles.dotSep}>·</span>
                        {p.city.name_ar}
                      </>
                    )}
                  </div>

                  <div className={styles.metaRow}>
                    <span className={`${styles.chip} ${chip.cls}`}>{chip.label}</span>
                    <span className={styles.uploaded}>رُفع: {formatDate(p.uploaded_at)}</span>
                  </div>

                  {p.payment_proof_url ? (
                    <div className={styles.proof} onClick={() => setLightbox(p.payment_proof_url)}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={p.payment_proof_url} alt="إيصال التحويل" />
                      <span className={styles.zoomBadge}>
                        <svg
                          width="13"
                          height="13"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="2.4"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        >
                          <circle cx="11" cy="11" r="8" />
                          <line x1="21" y1="21" x2="16.65" y2="16.65" />
                          <line x1="11" y1="8" x2="11" y2="14" />
                          <line x1="8" y1="11" x2="14" y2="11" />
                        </svg>
                        تكبير
                      </span>
                    </div>
                  ) : (
                    <div className={styles.noProof}>لا يوجد إيصال مرفوع</div>
                  )}

                  {p.payment_review_note && p.payment_status === 'failed' && (
                    <div className={styles.noteBox}>سبب الرفض: {p.payment_review_note}</div>
                  )}

                  {isPaid ? (
                    <div className={styles.settledRow}>
                      <svg
                        width="16"
                        height="16"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2.4"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M20 6 9 17l-5-5" />
                      </svg>
                      تم اعتماد التحويل {p.paid_at ? `· ${formatDate(p.paid_at)}` : ''}
                    </div>
                  ) : (
                    <div className={styles.actions}>
                      <button
                        className={`${styles.btn} ${styles.approve}`}
                        disabled={busyId === p.id || !p.payment_proof_url}
                        onClick={() => openModal('approve', p)}
                      >
                        ✓ اعتماد العمولة
                      </button>
                      <button
                        className={`${styles.btn} ${styles.reject}`}
                        disabled={busyId === p.id}
                        onClick={() => openModal('reject', p)}
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
                صفحة {page} من {data.pagination.last_page} · {data.pagination.total} تحويل
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

      {/* ── Lightbox ── */}
      {lightbox && (
        <div className={styles.lightbox} onClick={() => setLightbox(null)}>
          <button className={styles.lightboxClose} onClick={() => setLightbox(null)}>
            ✕
          </button>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightbox} alt="إيصال التحويل" onClick={(e) => e.stopPropagation()} />
        </div>
      )}

      {/* ── Approve / Reject modal ── */}
      {modal && (
        <div className={styles.modalOverlay} onClick={() => !modalBusy && setModal(null)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            {modal.type === 'approve' ? (
              <>
                <div className={`${styles.modalIcon} ${styles.modalIconApprove}`}>✅</div>
                <div className={styles.modalTitle}>اعتماد تحويل العمولة</div>
                <p className={styles.modalText}>
                  سيتم اعتماد عمولة قدرها <b>{formatCurrency(modal.item.payment_amount)}</b> للإعلان{' '}
                  <b>#{modal.item.id}</b> من البائع <b>{modal.item.user?.name || 'مجهول'}</b>. تأكّد
                  من مطابقة الإيصال للمبلغ قبل الاعتماد.
                </p>
                <div className={styles.modalActions}>
                  <button
                    className={`${styles.modalBtn} ${styles.modalCancel}`}
                    disabled={modalBusy}
                    onClick={() => setModal(null)}
                  >
                    إلغاء
                  </button>
                  <button
                    className={`${styles.modalBtn} ${styles.modalConfirmApprove}`}
                    disabled={modalBusy}
                    onClick={confirmApprove}
                  >
                    {modalBusy ? 'جارٍ الاعتماد...' : 'اعتماد العمولة'}
                  </button>
                </div>
              </>
            ) : (
              <>
                <div className={`${styles.modalIcon} ${styles.modalIconReject}`}>⚠️</div>
                <div className={styles.modalTitle}>رفض إيصال التحويل</div>
                <p className={styles.modalText}>
                  سيظهر سبب الرفض للبائع ليتمكّن من إعادة رفع إيصال صحيح للإعلان{' '}
                  <b>#{modal.item.id}</b>.
                </p>
                <label className={styles.modalLabel}>سبب الرفض</label>
                <textarea
                  className={styles.textarea}
                  placeholder="مثال: المبلغ المحوّل لا يطابق العمولة المستحقة، أو الإيصال غير واضح..."
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  autoFocus
                />
                <div className={styles.modalActions}>
                  <button
                    className={`${styles.modalBtn} ${styles.modalCancel}`}
                    disabled={modalBusy}
                    onClick={() => setModal(null)}
                  >
                    إلغاء
                  </button>
                  <button
                    className={`${styles.modalBtn} ${styles.modalConfirmReject}`}
                    disabled={modalBusy || !rejectReason.trim()}
                    onClick={confirmReject}
                  >
                    {modalBusy ? 'جارٍ الرفض...' : 'تأكيد الرفض'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {/* ── Toast ── */}
      {toast && (
        <div
          className={`${styles.toast} ${toast.kind === 'ok' ? styles.toastOk : styles.toastErr}`}
        >
          {toast.kind === 'ok' ? '✓' : '✕'} {toast.msg}
        </div>
      )}
    </div>
  );
}
