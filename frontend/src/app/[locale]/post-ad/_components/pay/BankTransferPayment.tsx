'use client';

import { useRef, useState } from 'react';
import Image from 'next/image';
import { BANK_ACCOUNT } from '@/lib/bankAccount';
import { uploadPaymentProof } from '@/lib/api/payments';
import type { Ad } from '@/lib/api/ads';

type Props = {
  adId: number;
  amount: number;
  /** Current review note (set when a previous receipt was rejected). */
  reviewNote?: string | null;
  /** Whether a receipt is already under review. */
  underReview?: boolean;
  /** Called after a receipt is uploaded and the ad transitions to under_review. */
  onSubmitted: (ad: Ad) => void;
};

// Mobile palette (matches the Flutter BankTransferScreen).
const NAVY = '#1B3A6B';
const INK = '#1A1A1A';
const GRAY = '#757575';
const MUTED = '#9E9E9E';
const BORDER = '#E5E7EB';

/**
 * Manual bank-transfer payment for the after-sale commission. Until the PSP
 * integration is live, sellers transfer the fee to the company account
 * (QR + details below) and upload a screenshot of the transfer. The receipt
 * then goes to admin review. White theme — mirrors the mobile screen.
 */
export function BankTransferPayment({ adId, amount, reviewNote, underReview, onSubmitted }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const copy = async (label: string, value: string) => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(label);
      setTimeout(() => setCopied(null), 1500);
    } catch {
      /* clipboard unavailable — ignore */
    }
  };

  const pickFile = (f: File | null) => {
    setError(null);
    setFile(f);
    setPreview(f ? URL.createObjectURL(f) : null);
  };

  const submit = async () => {
    if (!file) {
      setError('يرجى إرفاق صورة إيصال التحويل أولاً.');
      return;
    }
    setLoading(true);
    setError(null);
    setProgress(0);
    try {
      const ad = await uploadPaymentProof(adId, file, setProgress);
      onSubmitted(ad);
    } catch (e) {
      setError((e as { message?: string })?.message ?? 'فشل رفع الإيصال — حاول مرة أخرى');
    } finally {
      setLoading(false);
    }
  };

  const row = (label: string, value: string) => (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
        padding: '12px 0',
        borderBottom: `1px solid ${BORDER}`,
      }}
    >
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: 12, color: MUTED, marginBottom: 3 }}>{label}</div>
        <div
          style={{
            fontSize: 14.5,
            fontWeight: 700,
            color: INK,
            letterSpacing: 0.3,
            wordBreak: 'break-all',
          }}
          dir="ltr"
        >
          {value}
        </div>
      </div>
      <button
        type="button"
        onClick={() => copy(label, value)}
        style={{
          flexShrink: 0,
          padding: '6px 14px',
          fontSize: 12.5,
          fontWeight: 600,
          fontFamily: 'inherit',
          cursor: 'pointer',
          color: NAVY,
          background: `${NAVY}0F`,
          border: `1px solid ${NAVY}33`,
          borderRadius: 99,
        }}
      >
        {copied === label ? '✓ تم النسخ' : 'نسخ'}
      </button>
    </div>
  );

  return (
    <div dir="rtl">
      {/* Intro + amount */}
      <div
        style={{
          padding: 16,
          background: `${NAVY}0A`,
          border: `1px solid ${NAVY}33`,
          borderRadius: 14,
        }}
      >
        <p style={{ fontSize: 13.5, lineHeight: 1.8, color: '#616161', margin: 0 }}>
          النشر مجاني، وتُستحق عمولة البيع الثابتة بعد إتمام البيع. بوابات الدفع الإلكتروني قيد
          التجهيز، لذا يتم حالياً سداد العمولة عبر التحويل البنكي ثم إرفاق صورة الإيصال لمراجعتها.
        </p>
        <div
          style={{
            marginTop: 14,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <span style={{ fontSize: 14, color: '#616161' }}>المبلغ المطلوب</span>
          <span style={{ fontSize: 20, fontWeight: 800, color: NAVY }}>
            {amount.toLocaleString('ar-SA')} ر.س
          </span>
        </div>
      </div>

      {/* QR */}
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 16 }}>
        <div
          style={{
            background: '#fff',
            border: `1px solid ${BORDER}`,
            borderRadius: 16,
            padding: 12,
            textAlign: 'center',
          }}
        >
          <Image
            src={BANK_ACCOUNT.qrImage}
            alt="QR التحويل البنكي"
            width={220}
            height={280}
            style={{ width: 220, height: 'auto', display: 'block' }}
          />
          <p style={{ fontSize: 12, color: MUTED, margin: '8px 0 0' }}>
            امسح رمز QR من تطبيق البنك للتحويل المباشر
          </p>
        </div>
      </div>

      {/* Bank details */}
      <div
        style={{
          marginTop: 16,
          padding: '0 16px',
          background: '#fff',
          border: `1px solid ${BORDER}`,
          borderRadius: 14,
        }}
      >
        {row('اسم المستفيد', BANK_ACCOUNT.accountName)}
        {row('البنك', BANK_ACCOUNT.bankName)}
        {row('رقم الحساب', BANK_ACCOUNT.accountNumber)}
        <div style={{ borderBottom: 'none' }}>{row('الآيبان (IBAN)', BANK_ACCOUNT.iban)}</div>
      </div>

      {reviewNote && !underReview && (
        <div
          style={{
            marginTop: 14,
            padding: 12,
            background: '#FEF2F2',
            border: '1px solid #FCA5A5',
            borderRadius: 12,
            fontSize: 13,
            color: '#B91C1C',
          }}
        >
          تم رفض الإيصال السابق: {reviewNote}
          <div style={{ marginTop: 4, color: '#616161' }}>
            يرجى إرفاق إيصال صحيح وإعادة الإرسال.
          </div>
        </div>
      )}

      {/* Upload receipt */}
      <div style={{ marginTop: 20 }}>
        <h4 style={{ fontSize: 15, fontWeight: 800, color: INK, margin: '0 0 10px' }}>
          إرفاق إيصال التحويل
        </h4>

        <input
          ref={inputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp"
          style={{ display: 'none' }}
          onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
        />

        <div
          onClick={() => !loading && inputRef.current?.click()}
          style={{
            cursor: loading ? 'default' : 'pointer',
            border: `1.5px dashed ${NAVY}66`,
            borderRadius: 14,
            padding: preview ? 12 : 28,
            textAlign: 'center',
            background: '#fff',
          }}
        >
          {preview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={preview}
              alt="معاينة الإيصال"
              style={{
                maxHeight: 240,
                maxWidth: '100%',
                borderRadius: 10,
                margin: '0 auto',
                display: 'block',
              }}
            />
          ) : (
            <div style={{ color: GRAY, fontSize: 13.5 }}>
              <div style={{ fontSize: 30, marginBottom: 6 }}>📤</div>
              اضغط لاختيار صورة إيصال التحويل
              <div style={{ fontSize: 11.5, marginTop: 4, color: MUTED }}>
                JPG أو PNG حتى 8 ميجابايت
              </div>
            </div>
          )}
        </div>
        {preview && !loading && (
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            style={{
              marginTop: 8,
              fontSize: 12.5,
              fontWeight: 600,
              fontFamily: 'inherit',
              color: NAVY,
              background: 'transparent',
              border: 'none',
              cursor: 'pointer',
            }}
          >
            ↺ تغيير الصورة
          </button>
        )}

        {/* Upload progress */}
        {loading && (
          <div style={{ marginTop: 12 }}>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                fontSize: 12.5,
                color: GRAY,
                marginBottom: 6,
              }}
            >
              <span>{progress < 100 ? 'جارٍ رفع الإيصال…' : 'جارٍ المعالجة…'}</span>
              <span style={{ fontWeight: 700, color: NAVY }}>{progress}%</span>
            </div>
            <div style={{ height: 8, borderRadius: 99, background: '#EDEFF3', overflow: 'hidden' }}>
              <div
                style={{
                  height: '100%',
                  width: `${progress}%`,
                  background: NAVY,
                  borderRadius: 99,
                  transition: 'width .2s ease',
                }}
              />
            </div>
          </div>
        )}

        {error && <p style={{ color: '#DC2626', fontSize: 12.5, marginTop: 10 }}>{error}</p>}

        <button
          type="button"
          onClick={submit}
          disabled={loading || !file}
          style={{
            width: '100%',
            marginTop: 14,
            padding: '14px 0',
            fontSize: 15,
            fontWeight: 700,
            fontFamily: 'inherit',
            color: '#fff',
            background: NAVY,
            border: 'none',
            borderRadius: 99,
            cursor: loading || !file ? 'not-allowed' : 'pointer',
            opacity: loading || !file ? 0.6 : 1,
          }}
        >
          {loading ? `جارٍ الرفع… ${progress}%` : 'إرسال الإيصال للمراجعة'}
        </button>
        <p style={{ marginTop: 10, fontSize: 11.5, color: MUTED, textAlign: 'center' }}>
          سيتم اعتماد دفع العمولة بعد التحقق من التحويل من قِبل الإدارة.
        </p>
      </div>
    </div>
  );
}
