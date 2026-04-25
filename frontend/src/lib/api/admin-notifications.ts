// ── Admin Notifications API — Sprint 17 ───────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

export interface CampaignItem {
  id: number;
  title_ar: string;
  title_en: string | null;
  target_type: string;
  target_type_label: string;
  status: string;
  status_label: string;
  recipients_count: number;
  delivered_count: number;
  scheduled_at: string | null;
  sent_at: string | null;
  admin: { id: number; name: string } | null;
  created_at: string;
}

export interface CampaignDetail extends CampaignItem {
  body_ar: string;
  body_en: string | null;
  target_city: { id: number; name_ar: string } | null;
  target_category: { id: number; name_ar: string } | null;
  target_user_ids: number[] | null;
  data: Record<string, unknown> | null;
  updated_at: string;
}

export interface NotificationStats {
  total_campaigns: number;
  sent_campaigns: number;
  draft_campaigns: number;
  scheduled_campaigns: number;
  total_recipients: number;
  total_notifications: number;
  unread_notifications: number;
}

export interface CampaignCreateData {
  title_ar: string;
  title_en?: string;
  body_ar: string;
  body_en?: string;
  target_type: string;
  target_city_id?: number;
  target_category_id?: number;
  target_user_ids?: number[];
  data?: Record<string, unknown>;
  scheduled_at?: string;
}

export interface PaginatedCampaigns {
  data: CampaignItem[];
  pagination: { current_page: number; last_page: number; per_page: number; total: number };
}

export async function fetchCampaigns(params: { status?: string; q?: string; page?: number } = {}): Promise<PaginatedCampaigns> {
  const qs = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => { if (v) qs.append(k, String(v)); });
  const url = `${ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGNS}${qs.toString() ? `?${qs}` : ''}`;
  const res = await apiClient.get<PaginatedCampaigns>(url);
  return res.data;
}

export async function fetchCampaignDetail(id: number): Promise<CampaignDetail> {
  const res = await apiClient.get<CampaignDetail>(ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGN_DETAIL(id));
  return res.data;
}

export async function createCampaign(data: CampaignCreateData) {
  return apiClient.post(ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGNS, data);
}

export async function updateCampaign(id: number, data: Partial<CampaignCreateData>) {
  return apiClient.put(ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGN_DETAIL(id), data);
}

export async function deleteCampaign(id: number) {
  return apiClient.delete(ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGN_DETAIL(id));
}

export async function sendCampaign(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGN_SEND(id), {});
}

export async function scheduleCampaign(id: number, scheduled_at: string) {
  return apiClient.post(ENDPOINTS.ADMIN_NOTIFICATION_CAMPAIGN_SCHEDULE(id), { scheduled_at });
}

export async function fetchNotificationStats(): Promise<NotificationStats> {
  const res = await apiClient.get<NotificationStats>(ENDPOINTS.ADMIN_NOTIFICATION_STATS);
  return res.data;
}
