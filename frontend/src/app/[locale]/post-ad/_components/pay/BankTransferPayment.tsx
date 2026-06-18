'use client';

import { useRef, useState } from 'react';
import Image from 'next/image';
import pm from '@/styles/premium.module.css';
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

/**
 * Manual bank-transfer payment for the publish fee. Until the PSP integration
 * is live, sellers transfer the fee to the company account (QR + details below)
 * and upload a screenshot of the transfer. The receipt then goes to admin
 * review before the ad is published.
 */
export function BankTransferPayment({ adId, amount, reviewNote, underReview, onSubmitted }: Props) {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
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
    try {
      const ad = await uploadPaymentProof(adId, file);
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
        padding: '10px 0',
        borderBottom: '1px solid rgba(255,255,255,0.08)',
      }}
    >
      <div style={{ minWidth: 0 }}>
        <div style={{ fontSize: 12, color: '#94a3b8', marginBottom: 2 }}>{label}</div>
        <div
          style={{ fontSize: 14, fontWeight: 700, letterSpacing: 0.3, wordBreak: 'break-all' }}
          dir="ltr"
        >
          {value}
        </div>
      </div>
      <button
        type="button"
        className={pm.pmBtn}
        style={{ flexShrink: 0, padding: '6px 12px', fontSize: 12.5 }}
        onClick={() => copy(label, value)}
      >
        {copied === label ? '✓ تم النسخ' : 'نسخ'}
      </button>
    </div>
  );

  return (
    <div>
      <div
        style={{
          padding: 16,
          background: 'rgba(255,255,255,0.03)',
          border: '1px solid rgba(255,255,255,0.1)',
          borderRadius: 14,
        }}
      >
        <p style={{ fontSize: 13.5, lineHeight: 1.7, color: '#cbd5e1', marginBottom: 14 }}>
          النشر مجاني، وتُستحق عمولة البيع الثابتة بعد إتمام البيع. بوابات الدفع الإلكتروني قيد
          التجهيز، لذا يتم حالياً سداد العمولة عبر التحويل البنكي. حوّل مبلغ{' '}
          <strong style={{ color: '#fff' }}>{amount.toLocaleString('ar-SA')} ر.س</strong> (شامل
          الضريبة) إلى الحساب التالي، ثم أرفق صورة إيصال التحويل ليراجعها الفريق.
        </p>

        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
          <div style={{ background: '#fff', borderRadius: 16, padding: 10 }}>
            <Image
              src={BANK_ACCOUNT.qrImage}
              alt="QR التحويل البنكي"
              width={220}
              height={280}
              style={{ width: 220, height: 'auto', display: 'block' }}
            />
          </div>
        </div>
        <p style={{ textAlign: 'center', fontSize: 12, color: '#94a3b8', marginBottom: 12 }}>
          امسح رمز QR من تطبيق البنك للتحويل المباشر
        </p>

        {row('اسم المستفيد', BANK_ACCOUNT.accountName)}
        {row('البنك', BANK_ACCOUNT.bankName)}
        {row('رقم الحساب', BANK_ACCOUNT.accountNumber)}
        {row('الآيبان (IBAN)', BANK_ACCOUNT.iban)}
      </div>

      {reviewNote && !underReview && (
        <div
          style={{
            marginTop: 14,
            padding: 12,
            background: 'rgba(239,68,68,0.1)',
            border: '1px solid rgba(239,68,68,0.3)',
            borderRadius: 12,
            fontSize: 13,
            color: '#fca5a5',
          }}
        >
          تم رفض الإيصال السابق: {reviewNote}
          <div style={{ marginTop: 4, color: '#cbd5e1' }}>
            يرجى إرفاق إيصال صحيح وإعادة الإرسال.
          </div>
        </div>
      )}

      <div style={{ marginTop: 18 }}>
        <h4 style={{ fontSize: 14.5, fontWeight: 700, marginBottom: 10 }}>إرفاق إيصال التحويل</h4>

        <input
          ref={inputRef}
          type="file"
          accept="image/png,image/jpeg,image/webp"
          style={{ display: 'none' }}
          onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
        />

        <div
          onClick={() => inputRef.current?.click()}
          style={{
            cursor: 'pointer',
            border: '1.5px dashed rgba(255,255,255,0.25)',
            borderRadius: 14,
            padding: preview ? 12 : 28,
            textAlign: 'center',
            background: 'rgba(255,255,255,0.02)',
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
            <div style={{ color: '#94a3b8', fontSize: 13.5 }}>
              <div style={{ fontSize: 28, marginBottom: 6 }}>📤</div>
              اضغط لاختيار صورة إيصال التحويل
              <div style={{ fontSize: 11.5, marginTop: 4 }}>JPG أو PNG حتى 8 ميجابايت</div>
            </div>
          )}
        </div>
        {preview && (
          <button
            type="button"
            className={pm.pmBtn}
            style={{ marginTop: 8, fontSize: 12.5 }}
            onClick={() => inputRef.current?.click()}
          >
            تغيير الصورة
          </button>
        )}

        {error && <p style={{ color: '#fca5a5', fontSize: 12.5, marginTop: 10 }}>{error}</p>}

        <button
          type="button"
          className={`${pm.pmBtn} ${pm.pmBtnPrimary}`}
          style={{ width: '100%', marginTop: 14 }}
          disabled={loading || !file}
          onClick={submit}
        >
          {loading ? 'جارٍ الرفع...' : 'إرسال الإيصال للمراجعة'}
        </button>
        <p className={pm.pmHelp} style={{ marginTop: 10 }}>
          سيتم اعتماد دفع العمولة بعد التحقق من التحويل من قِبل الإدارة.
        </p>
      </div>
    </div>
  );
}
