import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface IBanner {
  id: number;
  title: string;
  image_url: string;
  image_url_mobile: string | null;
  link_type: 'ad' | 'whatsapp' | 'url' | 'none';
  link_ad_id: number | null;
  link_whatsapp: string | null;
  link_url: string | null;
  position: string;
  sort_order: number;
}

// ── API functions ─────────────────────────────────────────────────────────────

export async function fetchBanners(position: string): Promise<IBanner[]> {
  const res = await apiClient.get<IBanner[]>(
    `${ENDPOINTS.BANNERS}?position=${position}`,
  );
  return res.data ?? [];
}

export async function trackBannerClick(
  bannerId: number,
): Promise<{ redirect_url: string | null }> {
  const res = await apiClient.post<{ redirect_url: string | null }>(
    ENDPOINTS.BANNER_CLICK(bannerId),
    {},
  );
  return res.data ?? { redirect_url: null };
}
