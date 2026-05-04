import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { PaginatedResponse } from './types';
import type { AdListItem } from './ads';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface SellerProfile {
  id: number;
  name: string;
  avatar: string | null;
  cover_image: string | null;
  bio: string | null;
  is_verified: boolean;
  is_dealer: boolean;
  avg_rating: number | string;
  rating_count: number;
  rating_distribution: Record<string, number>;
  active_ads_count: number;
  sold_ads_count: number;
  total_ads_count: number;
  member_since: string | null;
  last_active_at: string | null;
}

// ── API functions ─────────────────────────────────────────────────────────────

export async function fetchSellerProfile(userId: number): Promise<SellerProfile> {
  const res = await apiClient.get<SellerProfile>(ENDPOINTS.USER_PROFILE(userId));
  return res.data!;
}

export async function fetchSellerAds(
  userId: number,
  page = 1,
  sort: 'newest' | 'price_asc' | 'price_desc' = 'newest',
): Promise<PaginatedResponse<AdListItem>> {
  return apiClient.getPaginated<AdListItem>(
    `${ENDPOINTS.USER_ADS(userId)}?page=${page}&sort=${sort}`,
  );
}
