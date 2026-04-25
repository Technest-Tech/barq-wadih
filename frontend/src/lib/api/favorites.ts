import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { PaginatedResponse } from './types';
import type { AdListItem } from './ads';

// ── API functions ─────────────────────────────────────────────────────────────

export async function toggleFavorite(
  adId: number,
): Promise<{ is_favorited: boolean }> {
  const res = await apiClient.post<{ is_favorited: boolean }>(
    ENDPOINTS.AD_FAVORITE(adId),
    {},
  );
  return res.data!;
}

export async function fetchFavoriteStatus(
  adId: number,
): Promise<{ is_favorited: boolean }> {
  const res = await apiClient.get<{ is_favorited: boolean }>(
    ENDPOINTS.AD_FAVORITE_STATUS(adId),
  );
  return res.data!;
}

export async function fetchFavorites(
  page = 1,
): Promise<PaginatedResponse<AdListItem>> {
  return apiClient.getPaginated<AdListItem>(
    `${ENDPOINTS.FAVORITES}?page=${page}`,
  );
}
