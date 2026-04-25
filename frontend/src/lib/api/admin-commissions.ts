// ── Admin Commissions API — Sprint 16 ─────────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ───────────────────────────────────────────────────────────────────

export interface CommissionItem {
  id: number;
  user: { id: number; name: string; phone: string | null; avatar: string | null } | null;
  ad: { id: number; title: string; price: number; status: string } | null;
  sale_price: number;
  commission_rate: number;
  commission_amount: number;
  is_flat_fee: boolean;
  status: string;
  status_label: string;
  payment_method: string | null;
  gateway_tx_id: string | null;
  paid_at: string | null;
  created_at: string;
}

export interface CommissionDetail extends CommissionItem {
  payment_gateway: string | null;
  gateway_response: Record<string, unknown> | null;
  updated_at: string;
  ad: {
    id: number;
    title: string;
    price: number;
    status: string;
    category: { id: number; name_ar: string } | null;
    city: { id: number; name_ar: string } | null;
    region: { id: number; name_ar: string } | null;
  } | null;
  user: {
    id: number;
    name: string;
    phone: string | null;
    email: string | null;
    avatar: string | null;
    is_verified: boolean;
  } | null;
}

export interface CommissionSummary {
  total_paid: number;
  total_pending: number;
  this_month: number;
  avg_commission: number;
  max_commission: number;
  total_count: number;
  by_status: { status: string; label: string; count: number }[];
}

export interface CommissionFilters {
  q?: string;
  status?: string;
  user_id?: string;
  from?: string;
  to?: string;
  min_amount?: string;
  max_amount?: string;
  sort?: string;
  dir?: string;
  page?: number;
  per_page?: number;
}

export interface PaginatedCommissions {
  data: CommissionItem[];
  pagination: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
}

// ── API Functions ───────────────────────────────────────────────────────────

export async function fetchCommissions(filters: CommissionFilters = {}): Promise<PaginatedCommissions> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== '') params.append(key, String(value));
  });
  const qs = params.toString();
  const url = `${ENDPOINTS.ADMIN_COMMISSIONS}${qs ? `?${qs}` : ''}`;
  const res = await apiClient.get<PaginatedCommissions>(url);
  return res.data;
}

export async function fetchCommissionDetail(id: number): Promise<CommissionDetail> {
  const res = await apiClient.get<CommissionDetail>(ENDPOINTS.ADMIN_COMMISSION_DETAIL(id));
  return res.data;
}

export async function updateCommissionStatus(id: number, status: string) {
  return apiClient.patch(ENDPOINTS.ADMIN_COMMISSION_STATUS(id), { status });
}

export async function fetchCommissionSummary(): Promise<CommissionSummary> {
  const res = await apiClient.get<CommissionSummary>(ENDPOINTS.ADMIN_COMMISSIONS_SUMMARY);
  return res.data;
}

export function getCommissionExportUrl(filters: CommissionFilters = {}): string {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== '') params.append(key, String(value));
  });
  const qs = params.toString();
  const base = (typeof window !== 'undefined' ? '' : '') + '/api' + ENDPOINTS.ADMIN_COMMISSIONS_EXPORT;
  return `${base}${qs ? `?${qs}` : ''}`;
}
