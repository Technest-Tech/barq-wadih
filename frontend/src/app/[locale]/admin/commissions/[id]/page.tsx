'use client';

import { useState, useEffect, use } from 'react';
import Link from 'next/link';
import { fetchCommissionDetail, updateCommissionStatus, type CommissionDetail } from '@/lib/api/admin-commissions';

function formatCurrency(n: number): string {
  return `${n.toLocaleString('ar-SA', { maximumFractionDigits: 2 })} ر.س`;
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('ar-SA', {
    year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
  });
}

const cardStyle: React.CSSProperties = {
  background: 'var(--admin-card-bg, #1a1f2e)',
  border: '1px solid var(--admin-border, rgba(255,255,255,0.06))',
  borderRadius: '14px',
  padding: '1.5rem',
  marginBottom: '1rem',
};

const labelStyle: React.CSSProperties = { fontSize: '.78rem', color: '#94a3b8', marginBottom: '.25rem' };
const valueStyle: React.CSSProperties = { fontSize: '.95rem', fontWeight: 600, color: '#f1f5f9' };
const rowStyle: React.CSSProperties = { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' };

export default function CommissionDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = use(params);
  const [commission, setCommission] = useState<CommissionDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    const id = parseInt(resolvedParams.id, 10);
    fetchCommissionDetail(id)
      .then(setCommission)
      .finally(() => setLoading(false));
  }, [resolvedParams.id]);

  const handleStatusChange = async (newStatus: string) => {
    if (!commission) return;
    setUpdating(true);
    try {
      await updateCommissionStatus(commission.id, newStatus);
      const updated = await fetchCommissionDetail(commission.id);
      setCommission(updated);
    } catch {
      alert('فشل تحديث الحالة');
    } finally {
      setUpdating(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '4rem', gap: '1rem', color: '#94a3b8' }}>
        <div style={{ width: 24, height: 24, border: '3px solid rgba(255,255,255,0.1)', borderTopColor: '#6366f1', borderRadius: '50%', animation: 'spin .7s linear infinite' }} />
        جاري التحميل...
      </div>
    );
  }

  if (!commission) {
    return (
      <div style={{ textAlign: 'center', padding: '4rem', color: '#94a3b8' }}>
        <p style={{ fontSize: '3rem', marginBottom: '1rem' }}>❌</p>
        <p>العمولة غير موجودة</p>
        <Link href="/ar/admin/commissions" style={{ color: '#a5b4fc', marginTop: '1rem', display: 'inline-block' }}>
          ← العودة للعمولات
        </Link>
      </div>
    );
  }

  const c = commission;
  const statusColors: Record<string, string> = {
    paid: '#22c55e',
    pending: '#f59e0b',
    not_applicable: '#94a3b8',
  };

  return (
    <div style={{ maxWidth: 900, margin: '0 auto' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <Link href="/ar/admin/commissions" style={{ fontSize: '.82rem', color: '#a5b4fc', textDecoration: 'none', marginBottom: '.5rem', display: 'block' }}>
            ← العودة للعمولات
          </Link>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9', margin: 0 }}>
            💰 عمولة #{c.id}
          </h1>
        </div>
        <span style={{
          background: `${statusColors[c.status] || '#94a3b8'}22`,
          color: statusColors[c.status] || '#94a3b8',
          padding: '6px 16px',
          borderRadius: '99px',
          fontWeight: 700,
          fontSize: '.9rem',
        }}>
          {c.status_label}
        </span>
      </div>

      {/* Commission Info */}
      <div style={cardStyle}>
        <h3 style={{ fontSize: '1rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 1rem' }}>💵 تفاصيل العمولة</h3>
        <div style={rowStyle}>
          <div><p style={labelStyle}>سعر البيع</p><p style={{ ...valueStyle, color: '#22c55e' }}>{formatCurrency(c.sale_price)}</p></div>
          <div><p style={labelStyle}>نسبة العمولة</p><p style={valueStyle}>{(c.commission_rate * 100).toFixed(1)}%</p></div>
          <div><p style={labelStyle}>مبلغ العمولة</p><p style={{ ...valueStyle, fontSize: '1.15rem' }}>{formatCurrency(c.commission_amount)}</p></div>
          <div><p style={labelStyle}>النوع</p><p style={valueStyle}>{c.is_flat_fee ? 'رسم ثابت' : 'نسبة مئوية'}</p></div>
          <div><p style={labelStyle}>طريقة الدفع</p><p style={valueStyle}>{c.payment_method || '—'}</p></div>
          <div><p style={labelStyle}>بوابة الدفع</p><p style={valueStyle}>{c.payment_gateway || '—'}</p></div>
          <div><p style={labelStyle}>رقم المعاملة</p><p style={valueStyle}>{c.gateway_tx_id || '—'}</p></div>
          <div><p style={labelStyle}>تاريخ الدفع</p><p style={valueStyle}>{c.paid_at ? formatDate(c.paid_at) : '—'}</p></div>
        </div>
      </div>

      {/* Status Actions */}
      <div style={cardStyle}>
        <h3 style={{ fontSize: '1rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 1rem' }}>⚙️ تغيير الحالة</h3>
        <div style={{ display: 'flex', gap: '.75rem', flexWrap: 'wrap' }}>
          {['paid', 'pending', 'not_applicable'].map(s => (
            <button
              key={s}
              disabled={c.status === s || updating}
              onClick={() => handleStatusChange(s)}
              style={{
                padding: '.6rem 1.5rem',
                borderRadius: '10px',
                border: c.status === s ? `2px solid ${statusColors[s]}` : '1px solid rgba(255,255,255,0.1)',
                background: c.status === s ? `${statusColors[s]}15` : 'transparent',
                color: statusColors[s],
                fontWeight: 600,
                fontFamily: 'inherit',
                fontSize: '.88rem',
                cursor: c.status === s ? 'default' : 'pointer',
                opacity: updating ? 0.5 : 1,
                transition: 'all .2s',
              }}
            >
              {s === 'paid' ? '✅ مدفوع' : s === 'pending' ? '⏳ معلّق' : '⚪ لا ينطبق'}
            </button>
          ))}
        </div>
      </div>

      {/* Related Ad */}
      {c.ad && (
        <div style={cardStyle}>
          <h3 style={{ fontSize: '1rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 1rem' }}>📢 الإعلان المرتبط</h3>
          <div style={rowStyle}>
            <div><p style={labelStyle}>العنوان</p><p style={valueStyle}>{c.ad.title}</p></div>
            <div><p style={labelStyle}>السعر</p><p style={{ ...valueStyle, color: '#22c55e' }}>{formatCurrency(c.ad.price)}</p></div>
            <div><p style={labelStyle}>التصنيف</p><p style={valueStyle}>{c.ad.category?.name_ar || '—'}</p></div>
            <div><p style={labelStyle}>المدينة</p><p style={valueStyle}>{c.ad.city?.name_ar || '—'}</p></div>
            <div><p style={labelStyle}>المنطقة</p><p style={valueStyle}>{c.ad.region?.name_ar || '—'}</p></div>
          </div>
        </div>
      )}

      {/* Related User */}
      {c.user && (
        <div style={cardStyle}>
          <h3 style={{ fontSize: '1rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 1rem' }}>👤 المستخدم</h3>
          <div style={rowStyle}>
            <div><p style={labelStyle}>الاسم</p><p style={valueStyle}>{c.user.name}</p></div>
            <div><p style={labelStyle}>الهاتف</p><p style={valueStyle} dir="ltr">{c.user.phone || '—'}</p></div>
            <div><p style={labelStyle}>البريد</p><p style={valueStyle}>{c.user.email || '—'}</p></div>
            <div><p style={labelStyle}>موثق</p><p style={valueStyle}>{c.user.is_verified ? '✅ نعم' : '❌ لا'}</p></div>
          </div>
          <Link href={`/ar/admin/users/${c.user.id}`} style={{ color: '#a5b4fc', fontSize: '.85rem', marginTop: '.75rem', display: 'inline-block' }}>
            عرض ملف المستخدم →
          </Link>
        </div>
      )}

      {/* Timeline */}
      <div style={cardStyle}>
        <h3 style={{ fontSize: '1rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 1rem' }}>📋 الجدول الزمني</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '.75rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '.75rem' }}>
            <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#6366f1', flexShrink: 0 }} />
            <span style={{ fontSize: '.88rem', color: '#f1f5f9' }}>
              تم إنشاء العمولة — {formatDate(c.created_at)}
            </span>
          </div>
          {c.paid_at && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '.75rem' }}>
              <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#22c55e', flexShrink: 0 }} />
              <span style={{ fontSize: '.88rem', color: '#f1f5f9' }}>
                تم الدفع — {formatDate(c.paid_at)}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
