import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { PaginatedResponse } from './types';
import type { AdListItem } from './ads';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface SellerProfile {
  id: number;
  name: string;
  /** Public @handle, e.g. "ahmd_aamr". Null only for pre-backfill rows. */
  username: string | null;
  /** Canonical shareable link, e.g. "https://barqwadih.com/@ahmd_aamr". */
  profile_url: string | null;
  avatar: string | null;
  cover_image: string | null;
  bio: string | null;
  is_verified: boolean;
  /** When the badge was granted. Null for sellers verified before the audit trail existed. */
  verified_at: string | null;
  is_dealer: boolean;
  avg_rating: number | string;
  rating_count: number;
  rating_distribution: Record<string, number>;
  active_ads_count: number;
  sold_ads_count: number;
  total_ads_count: number;
  member_since: string | null;
  last_active_at: string | null;
  /** Whether the signed-in viewer may leave a profile review for this seller. */
  can_review: boolean;
  /** The viewer's own profile review, when they have already written one. */
  my_review: { id: number; stars: number; comment: string | null; created_at: string | null } | null;
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
