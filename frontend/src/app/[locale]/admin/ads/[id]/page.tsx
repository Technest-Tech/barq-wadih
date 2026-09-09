'use client';

import { use, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import {
  fetchAdminAd,
  approveAd,
  rejectAd,
  deleteAd,
  restoreAd,
  type AdminAd,
} from '@/lib/api/admin';
import s from '../../admin-shared.module.css';
import d from './ad-detail.module.css';

const STATUS_MAP: Record<string, { label: string; cls: string }> = {
  active: { label: 'نشط', cls: 'green' },
  sold: { label: 'مُباع', cls: 'blue' },
  expired: { label: 'منتهي', cls: 'gray' },
  pending_review: { label: 'قيد المراجعة', cls: 'yellow' },
  draft: { label: 'مسودة', cls: 'gray' },
  rejected: { label: 'مرفوض', cls: 'red' },
  deleted: { label: 'محذوف', cls: 'red' },
};

const MOD_MAP: Record<string, { label: string; cls: string }> = {
  approved: { label: 'مقبول', cls: 'green' },
  flagged: { label: 'مُبلّغ', cls: 'yellow' },
  under_review: { label: 'قيد المراجعة', cls: 'yellow' },
  rejected: { label: 'مرفوض', cls: 'red' },
};

const PAYMENT_MAP: Record<string, { label: string; cls: string }> = {
  paid: { label: 'مدفوعة', cls: 'green' },
  under_review: { label: 'قيد المراجعة', cls: 'yellow' },
  pending: { label: 'بانتظار الدفع', cls: 'gray' },
  failed: { label: 'مرفوضة', cls: 'red' },
};

type ModalType = { type: 'reject' | 'delete' } | null;

export default function AdminAdDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const adId = Number(id);

  const [ad, setAd] = useState<AdminAd | null>(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);
  const [modal, setModal] = useState<ModalType>(null);
  const [reason, setReason] = useState('');
  const [activeImage, setActiveImage] = useState(0);
  const [lightbox, setLightbox] = useState<string | null>(null);

  const showToast = (msg: string, type: 'success' | 'error') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchAdminAd(adId);
      setAd(data);
      setNotFound(false);
      setActiveImage(0);
    } catch (e) {
      // A missing / deleted ad id is the common case here — show the empty
      // state instead of an error toast that leaves a blank page behind it.
      setNotFound(true);
      showToast(e instanceof Error ? e.message : 'تعذّر تحميل الإعلان', 'error');
    } finally {
      setLoading(false);
    }
  }, [adId]);

  useEffect(() => {
    if (Number.isFinite(adId)) load();
    else {
      setNotFound(true);
      setLoading(false);
    }
  }, [adId, load]);

  const closeModal = () => {
    setModal(null);
    setReason('');
  };

  const handleApprove = async () => {
    setBusy(true);
    try {
      await approveAd(adId);
      showToast('تم قبول الإعلان', 'success');
      await load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const handleReject = async () => {
    if (!reason.trim()) return;
    setBusy(true);
    try {
      await rejectAd(adId, reason.trim());
      showToast('تم رفض الإعلان', 'success');
      closeModal();
      await load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const handleDelete = async () => {
    setBusy(true);
    try {
      await deleteAd(adId, reason.trim() || undefined);
      showToast('تم حذف الإعلان', 'success');
      closeModal();
      await load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const handleRestore = async () => {
    setBusy(true);
    try {
      await restoreAd(adId);
      showToast('تم استعادة الإعلان', 'success');
      await load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'خطأ', 'error');
    } finally {
      setBusy(false);
    }
  };

  const fmtDate = (v?: string | null) =>
    v
      ? new Date(v).toLocaleDateString('ar-SA', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        })
      : '—';

  const fmtMoney = (n: number) => `${n.toLocaleString('ar-SA', { maximumFractionDigits: 2 })} ر.س`;

  if (loading) {
    return (
      <div className={s.page}>
        <div className={s.loading}>
          <div className={s.spinner} />
          <span>جاري التحميل...</span>
        </div>
      </div>
    );
  }

  if (notFound || !ad) {
    return (
      <div className={s.page}>
        <div className={s.empty}>
          <h3>الإعلان غير موجود</h3>
          <p>لم يُعثر على إعلان بالرقم #{id}. قد يكون حُذف نهائياً.</p>
          <Link href="/admin/ads" className={`${s.btn} ${d.backBtn}`}>
            ← العودة لقائمة الإعلانات
          </Link>
        </div>
      </div>
    );
  }

  const status = STATUS_MAP[ad.status] || { label: ad.status_label || ad.status, cls: 'gray' };
  const mod = MOD_MAP[ad.moderation_status] || {
    label: ad.moderation_label || ad.moderation_status,
    cls: 'gray',
  };
  const pay = ad.payment_status ? PAYMENT_MAP[ad.payment_status] : null;
  const images = ad.images ?? [];
  const isDeleted = Boolean(ad.deleted_at);

  return (
    <div className={s.page}>
      {toast && <div className={`${s.toast} ${s[toast.type]}`}>{toast.msg}</div>}

      {/* ── Reject / Delete modal ── */}
      {modal && (
        <div className={s.modalOverlay} onClick={closeModal}>
          <div className={s.modal} onClick={(e) => e.stopPropagation()}>
            <h3 className={s.modalTitle}>
              {modal.type === 'reject' ? '❌ رفض الإعلان' : '🗑️ حذف الإعلان'}
            </h3>
            <p className={s.modalBody}>الإعلان: &quot;{ad.title}&quot;</p>
            <div className={s.modalField}>
              <label className={s.modalLabel}>
                {modal.type === 'reject' ? 'سبب الرفض *' : 'ملاحظة (اختياري)'}
              </label>
              <textarea
                className={s.modalTextarea}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder={modal.type === 'reject' ? 'اكتب سبب الرفض...' : 'ملاحظة إدارية...'}
              />
            </div>
            <div className={s.modalActions}>
              <button
                className={`${s.btn} ${s.danger}`}
                onClick={modal.type === 'reject' ? handleReject : handleDelete}
                disabled={busy || (modal.type === 'reject' && !reason.trim())}
              >
                {busy ? 'جارٍ التنفيذ...' : 'تأكيد'}
              </button>
              <button className={s.btn} onClick={closeModal} disabled={busy}>
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Lightbox ── */}
      {lightbox && (
        <div className={d.lightbox} onClick={() => setLightbox(null)}>
          <button className={d.lightboxClose} onClick={() => setLightbox(null)}>
            ✕
          </button>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightbox} alt="صورة الإعلان" onClick={(e) => e.stopPropagation()} />
        </div>
      )}

      {/* ── Header ── */}
      <div className={s.pageHeader}>
        <div className={d.headerMain}>
          <Link href="/admin/ads" className={d.backLink}>
            ← الإعلانات
          </Link>
          <h1 className={s.pageTitle}>
            {ad.title} <span className={d.adId}>#{ad.id}</span>
          </h1>
          <div className={d.badgeRow}>
            <span className={`${s.badge} ${s[status.cls]}`}>{status.label}</span>
            <span className={`${s.badge} ${s[mod.cls]}`}>مراجعة: {mod.label}</span>
            {pay && <span className={`${s.badge} ${s[pay.cls]}`}>العمولة: {pay.label}</span>}
            {isDeleted && <span className={`${s.badge} ${s.red}`}>محذوف</span>}
          </div>
        </div>

        <div className={d.actions}>
          <Link
            href={`/ads/${ad.id}`}
            target="_blank"
            rel="noopener noreferrer"
            className={s.btn}
          >
            👁️ عرض في الموقع
          </Link>
          {!isDeleted && ad.moderation_status !== 'approved' && (
            <button
              className={`${s.btn} ${s.success}`}
              onClick={handleApprove}
              disabled={busy}
            >
              ✅ قبول
            </button>
          )}
          {!isDeleted && (
            <button
              className={`${s.btn} ${s.warning}`}
              onClick={() => setModal({ type: 'reject' })}
              disabled={busy}
            >
              ❌ رفض
            </button>
          )}
          {isDeleted ? (
            <button className={`${s.btn} ${s.success}`} onClick={handleRestore} disabled={busy}>
              ♻️ استعادة
            </button>
          ) : (
            <button
              className={`${s.btn} ${s.danger}`}
              onClick={() => setModal({ type: 'delete' })}
              disabled={busy}
            >
              🗑️ حذف
            </button>
          )}
        </div>
      </div>

      {ad.moderation_note && (
        <div className={d.noteBanner}>
          <strong>ملاحظة المراجعة:</strong> {ad.moderation_note}
        </div>
      )}

      {/* ── Stat strip ── */}
      <div className={d.statGrid}>
        <div className={d.stat}>
          <span className={d.statValue}>{ad.is_free ? 'مجاني' : fmtMoney(ad.price)}</span>
          <span className={d.statLabel}>السعر {ad.is_negotiable ? '(قابل للتفاوض)' : ''}</span>
        </div>
        <div className={d.stat}>
          <span className={d.statValue}>{(ad.views_count ?? 0).toLocaleString('ar-SA')}</span>
          <span className={d.statLabel}>مشاهدة</span>
        </div>
        <div className={d.stat}>
          <span className={d.statValue}>{(ad.favorites_count ?? 0).toLocaleString('ar-SA')}</span>
          <span className={d.statLabel}>مفضّلة</span>
        </div>
        <div className={d.stat}>
          <span className={d.statValue}>{(ad.chats_count ?? 0).toLocaleString('ar-SA')}</span>
          <span className={d.statLabel}>محادثة</span>
        </div>
        <div className={`${d.stat} ${ad.reports_count > 0 ? d.statAlert : ''}`}>
          <span className={d.statValue}>{(ad.reports_count ?? 0).toLocaleString('ar-SA')}</span>
          <span className={d.statLabel}>بلاغ</span>
        </div>
      </div>

      <div className={d.columns}>
        {/* ── Left column ── */}
        <div className={d.colMain}>
          {/* Gallery */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>🖼️ الصور ({images.length})</h3>
            {images.length === 0 ? (
              <div className={d.noImages}>لا توجد صور مرفوعة</div>
            ) : (
              <>
                <div
                  className={d.mainImage}
                  onClick={() => setLightbox(images[activeImage]?.url ?? null)}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={images[activeImage]?.url} alt={ad.title} />
                </div>
                {images.length > 1 && (
                  <div className={d.thumbs}>
                    {images.map((img, i) => (
                      <button
                        key={img.id}
                        className={`${d.thumb} ${i === activeImage ? d.thumbActive : ''}`}
                        onClick={() => setActiveImage(i)}
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={img.url} alt="" />
                      </button>
                    ))}
                  </div>
                )}
              </>
            )}
          </div>

          {/* Description */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>📝 الوصف</h3>
            <p className={d.description}>{ad.description || '—'}</p>
          </div>

          {/* Dynamic fields */}
          {ad.field_values && ad.field_values.length > 0 && (
            <div className={s.card}>
              <h3 className={s.cardTitle}>🏷️ تفاصيل التصنيف</h3>
              <div className={d.fieldGrid}>
                {ad.field_values.map((f) => (
                  <div key={f.field_key} className={d.fieldItem}>
                    <span className={d.fieldLabel}>{f.label_ar || f.field_key}</span>
                    <span className={d.fieldValue}>{f.value || '—'}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Reports */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>⚠️ البلاغات ({ad.reports_count ?? 0})</h3>
            {!ad.reports || ad.reports.length === 0 ? (
              <div className={d.muted}>لا توجد بلاغات على هذا الإعلان.</div>
            ) : (
              <div className={d.reportList}>
                {ad.reports.map((r) => (
                  <div key={r.id} className={d.report}>
                    <div className={d.reportTop}>
                      <span className={`${s.badge} ${s.red}`}>{r.reason_label || r.reason}</span>
                      <span className={`${s.badge} ${s.gray}`}>{r.status_label || r.status}</span>
                      <span className={d.reportDate}>{fmtDate(r.created_at)}</span>
                    </div>
                    {r.description && <p className={d.reportBody}>{r.description}</p>}
                    <div className={d.reportMeta}>
                      المُبلِّغ: {r.reporter?.name || 'مجهول'}
                      {r.admin_note ? ` · ملاحظة الإدارة: ${r.admin_note}` : ''}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* ── Right column ── */}
        <div className={d.colSide}>
          {/* Seller */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>👤 المُعلن</h3>
            {ad.user ? (
              <>
                <div className={d.sellerRow}>
                  {ad.user.avatar_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={ad.user.avatar_url} alt="" className={s.avatarImg} />
                  ) : (
                    <div className={s.avatar}>{ad.user.name?.[0] || '?'}</div>
                  )}
                  <div>
                    <div className={d.sellerName}>{ad.user.name}</div>
                    <div className={d.sellerRole}>{ad.user.role}</div>
                  </div>
                </div>
                <dl className={d.infoList}>
                  <div>
                    <dt>الجوال</dt>
                    <dd dir="ltr">{ad.user.phone || '—'}</dd>
                  </div>
                  <div>
                    <dt>البريد</dt>
                    <dd dir="ltr">{ad.user.email || '—'}</dd>
                  </div>
                  <div>
                    <dt>موثّق</dt>
                    <dd>{ad.user.is_verified ? 'نعم' : 'لا'}</dd>
                  </div>
                </dl>
                <Link href={`/admin/users/${ad.user.id}`} className={`${s.btn} ${d.fullBtn}`}>
                  عرض ملف المستخدم
                </Link>
              </>
            ) : (
              <div className={d.muted}>غير متوفر</div>
            )}
          </div>

          {/* Placement */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>📍 التصنيف والموقع</h3>
            <dl className={d.infoList}>
              <div>
                <dt>التصنيف</dt>
                <dd>{ad.category?.name_ar || '—'}</dd>
              </div>
              <div>
                <dt>المنطقة</dt>
                <dd>{ad.region?.name_ar || '—'}</dd>
              </div>
              <div>
                <dt>المدينة</dt>
                <dd>{ad.city?.name_ar || '—'}</dd>
              </div>
              <div>
                <dt>هاتف التواصل</dt>
                <dd dir="ltr">{ad.contact_phone || '—'}</dd>
              </div>
              <div>
                <dt>واتساب</dt>
                <dd dir="ltr">{ad.contact_whatsapp || '—'}</dd>
              </div>
            </dl>
          </div>

          {/* Commission / payment */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>💰 العمولة والتحويل</h3>
            <dl className={d.infoList}>
              <div>
                <dt>قيمة العمولة</dt>
                <dd>{fmtMoney(ad.commission_amount ?? 0)}</dd>
              </div>
              <div>
                <dt>حالة العمولة</dt>
                <dd>{ad.commission_status || '—'}</dd>
              </div>
              <div>
                <dt>المبلغ المحوَّل</dt>
                <dd>{fmtMoney(ad.payment_amount ?? 0)}</dd>
              </div>
              <div>
                <dt>حالة التحويل</dt>
                <dd>{pay?.label || ad.payment_status || '—'}</dd>
              </div>
              <div>
                <dt>رُفع الإيصال</dt>
                <dd>{fmtDate(ad.payment_proof_uploaded_at)}</dd>
              </div>
              <div>
                <dt>تاريخ الاعتماد</dt>
                <dd>{fmtDate(ad.paid_at)}</dd>
              </div>
            </dl>
            {ad.payment_review_note && (
              <div className={d.noteBox}>سبب رفض الإيصال: {ad.payment_review_note}</div>
            )}
            {ad.payment_proof_url && (
              <div className={d.proof} onClick={() => setLightbox(ad.payment_proof_url)}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={ad.payment_proof_url} alt="إيصال التحويل" />
                <span className={d.proofHint}>اضغط للتكبير</span>
              </div>
            )}
            {ad.payment_status === 'under_review' && (
              <Link href="/admin/payment-proofs" className={`${s.btn} ${d.fullBtn}`}>
                مراجعة التحويلات
              </Link>
            )}
          </div>

          {/* Timestamps */}
          <div className={s.card}>
            <h3 className={s.cardTitle}>🕒 التواريخ</h3>
            <dl className={d.infoList}>
              <div>
                <dt>أُنشئ</dt>
                <dd>{fmtDate(ad.created_at)}</dd>
              </div>
              <div>
                <dt>نُشر</dt>
                <dd>{fmtDate(ad.published_at)}</dd>
              </div>
              <div>
                <dt>ينتهي</dt>
                <dd>{fmtDate(ad.expires_at)}</dd>
              </div>
              <div>
                <dt>أُعلن البيع</dt>
                <dd>{fmtDate(ad.sale_declared_at)}</dd>
              </div>
              <div>
                <dt>حُذف</dt>
                <dd>{fmtDate(ad.deleted_at)}</dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </div>
  );
}
