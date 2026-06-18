// ── Admin Bank-Transfer Payment Proofs API ────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

export interface PaymentProofItem {
  id: number;
  title: string;
  payment_status: string;
  payment_amount: number;
  payment_proof_url: string | null;
  payment_review_note: string | null;
  uploaded_at: string | null;
  paid_at: string | null;
  created_at: string | null;
  category: { id: number; name_ar: string } | null;
  city: { id: number; name_ar: string } | null;
  user: {
    id: number;
    name: string;
    phone: string | null;
    email: string | null;
    avatar: string | null;
  } | null;
}

export interface PaymentProofFilters {
  status?: string;
  q?: string;
  page?: number;
  per_page?: number;
}

export interface PaginatedPaymentProofs {
  data: PaymentProofItem[];
  pagination: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
}

export async function fetchPaymentProofs(
  filters: PaymentProofFilters = {}
): Promise<PaginatedPaymentProofs> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== '') params.append(key, String(value));
  });
  const qs = params.toString();
  const url = `${ENDPOINTS.ADMIN_PAYMENT_PROOFS}${qs ? `?${qs}` : ''}`;
  const res = await apiClient.get<PaginatedPaymentProofs>(url);
  return res.data;
}

export async function fetchPaymentProofPendingCount(): Promise<number> {
  const res = await apiClient.get<{ count: number }>(ENDPOINTS.ADMIN_PAYMENT_PROOFS_PENDING_COUNT);
  return res.data.count;
}

export async function approvePaymentProof(adId: number): Promise<PaymentProofItem> {
  const res = await apiClient.post<PaymentProofItem>(
    ENDPOINTS.ADMIN_PAYMENT_PROOF_APPROVE(adId),
    {}
  );
  return res.data;
}

export async function rejectPaymentProof(adId: number, reason: string): Promise<PaymentProofItem> {
  const res = await apiClient.post<PaymentProofItem>(ENDPOINTS.ADMIN_PAYMENT_PROOF_REJECT(adId), {
    reason,
  });
  return res.data;
}
