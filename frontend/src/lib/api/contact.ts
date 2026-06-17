import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface FaqItem {
  q: string;
  a: string;
}

export interface ContactCategory {
  slug: string;
  label: string;
  faqs: FaqItem[];
}

export interface ContactSubmitPayload {
  name: string;
  email: string;
  phone?: string;
  category?: string;
  message: string;
}

export interface ContactSubmission {
  id: number;
  user_id: number | null;
  name: string;
  email: string;
  phone: string | null;
  category: string;
  category_label: string;
  message: string;
  status: 'pending' | 'in_progress' | 'resolved';
  admin_note: string | null;
  resolved_at: string | null;
  created_at: string;
  user?: { id: number; name: string; email: string } | null;
}

// ── Public API ────────────────────────────────────────────────────────────────

export async function fetchContactCategories(): Promise<ContactCategory[]> {
  const res = await apiClient.get<ContactCategory[]>(ENDPOINTS.CONTACT_CATEGORIES);
  return res.data;
}

export async function submitContact(payload: ContactSubmitPayload): Promise<void> {
  await apiClient.post<{ message: string }>(ENDPOINTS.CONTACT_SUBMIT, payload);
}

// ── Admin API ─────────────────────────────────────────────────────────────────

export async function fetchAdminContacts(params?: {
  status?: string;
  category?: string;
  search?: string;
  page?: number;
  per_page?: number;
}): Promise<{
  data: ContactSubmission[];
  meta: { current_page: number; last_page: number; total: number };
}> {
  const qs = new URLSearchParams();
  if (params?.status) qs.set('status', params.status);
  if (params?.category) qs.set('category', params.category);
  if (params?.search) qs.set('search', params.search);
  if (params?.page) qs.set('page', String(params.page));
  if (params?.per_page) qs.set('per_page', String(params.per_page));

  const url = `${ENDPOINTS.ADMIN_CONTACT}${qs.toString() ? '?' + qs.toString() : ''}`;
  const res = await apiClient.getPaginated<ContactSubmission>(url);
  return { data: res.data, meta: res.meta };
}

export async function fetchAdminContact(id: number): Promise<ContactSubmission> {
  const res = await apiClient.get<ContactSubmission>(ENDPOINTS.ADMIN_CONTACT_DETAIL(id));
  return res.data;
}

export async function updateContactStatus(
  id: number,
  payload: { status: 'pending' | 'in_progress' | 'resolved'; admin_note?: string }
): Promise<ContactSubmission> {
  const res = await apiClient.patch<ContactSubmission>(ENDPOINTS.ADMIN_CONTACT_STATUS(id), payload);
  return res.data;
}
