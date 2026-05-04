import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface FollowToggleResult {
  is_following: boolean;
  followers_count: number;
}

export interface FollowedSellerSummary {
  id: number;
  name: string;
  avatar: string | null;
  is_verified: boolean;
  is_dealer: boolean;
  avg_rating: number | string | null;
  rating_count: number;
  total_ads_count: number;
  active_ads_count: number;
}

export interface FollowedSellerEntry {
  id: number;
  seller: FollowedSellerSummary;
  created_at: string | null;
}

// ── API functions ────────────────────────────────────────────────────────────

export async function toggleSellerFollow(userId: number): Promise<FollowToggleResult> {
  const res = await apiClient.post<FollowToggleResult>(
    ENDPOINTS.USER_FOLLOW(userId),
    {},
  );
  return res.data!;
}

export async function fetchSellerFollowStatus(userId: number): Promise<FollowToggleResult> {
  const res = await apiClient.get<FollowToggleResult>(
    ENDPOINTS.USER_FOLLOW_STATUS(userId),
  );
  return res.data!;
}

export async function fetchFollowedSellers(): Promise<FollowedSellerEntry[]> {
  const res = await apiClient.get<FollowedSellerEntry[]>(ENDPOINTS.SELLER_FOLLOWS);
  return res.data ?? [];
}
