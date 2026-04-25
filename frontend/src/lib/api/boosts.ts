import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { Ad } from './ads';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface BoostConfig {
  premium_duration_hours: number;
  premium_price: number;
  refresh_cooldown_hours: number;
  max_active_boosts: number;
  is_free_period: boolean;
}

export interface BoostHistoryItem {
  id: number;
  boost_type: 'refresh' | 'premium';
  label: string;
  boosted_at: string;
  expires_at: string | null;
  is_expired: boolean;
}

// ── API functions ─────────────────────────────────────────────────────────────

export async function fetchBoostConfig(): Promise<BoostConfig> {
  const res = await apiClient.get<BoostConfig>(ENDPOINTS.BOOST_CONFIG);
  return res.data;
}

export async function boostAd(adId: number): Promise<Ad> {
  const res = await apiClient.post<Ad>(ENDPOINTS.AD_BOOST(adId), {});
  return res.data;
}

export async function refreshAd(adId: number): Promise<Ad> {
  const res = await apiClient.post<Ad>(ENDPOINTS.AD_REFRESH(adId), {});
  return res.data;
}

export async function fetchBoostHistory(adId: number): Promise<BoostHistoryItem[]> {
  const res = await apiClient.get<BoostHistoryItem[]>(
    ENDPOINTS.AD_BOOST_HISTORY(adId),
  );
  return res.data ?? [];
}
