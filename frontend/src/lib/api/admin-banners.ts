// ── Admin Banners API — Sprint 17 ─────────────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

export interface BannerItem {
  id: number;
  title: string;
  image_url: string | null;
  image_url_mobile: string | null;
  link_type: string;
  link_type_label: string;
  position: string;
  position_label: string;
  sort_order: number;
  is_active: boolean;
  is_live: boolean;
  starts_at: string | null;
  ends_at: string | null;
  impressions_count: number;
  clicks_count: number;
  ctr: number;
  advertiser_name: string | null;
  created_at: string;
}

export interface BannerDetail extends BannerItem {
  link_ad_id: number | null;
  linked_ad: { id: number; title: string } | null;
  link_whatsapp: string | null;
  link_url: string | null;
  advertiser_phone: string | null;
  notes: string | null;
  updated_at: string;
}

export interface BannerAnalytics {
  impressions: number;
  clicks: number;
  ctr: number;
  daily_clicks: { date: string; label: string; count: number }[];
  platforms: { platform: string; count: number }[];
}

export interface PaginatedBanners {
  data: BannerItem[];
  pagination: { current_page: number; last_page: number; per_page: number; total: number };
}

export async function fetchBanners(params: { position?: string; status?: string; q?: string; page?: number } = {}): Promise<PaginatedBanners> {
  const qs = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => { if (v) qs.append(k, String(v)); });
  const url = `${ENDPOINTS.ADMIN_BANNERS}${qs.toString() ? `?${qs}` : ''}`;
  const res = await apiClient.get<PaginatedBanners>(url);
  return res.data;
}

export async function fetchBannerDetail(id: number): Promise<BannerDetail> {
  const res = await apiClient.get<BannerDetail>(ENDPOINTS.ADMIN_BANNER_DETAIL(id));
  return res.data;
}

export async function createBanner(formData: FormData) {
  return apiClient.post(ENDPOINTS.ADMIN_BANNERS, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
}

export async function updateBanner(id: number, formData: FormData) {
  return apiClient.put(ENDPOINTS.ADMIN_BANNER_DETAIL(id), formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
}

export async function deleteBanner(id: number) {
  return apiClient.delete(ENDPOINTS.ADMIN_BANNER_DETAIL(id));
}

export async function toggleBanner(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_BANNER_TOGGLE(id), {});
}

export async function fetchBannerAnalytics(id: number): Promise<BannerAnalytics> {
  const res = await apiClient.get<BannerAnalytics>(ENDPOINTS.ADMIN_BANNER_ANALYTICS(id));
  return res.data;
}
