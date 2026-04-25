import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── API functions ─────────────────────────────────────────────────────────────

export async function toggleCategoryFollow(
  categoryId: number,
  cityId?: number,
): Promise<{ is_following: boolean }> {
  const res = await apiClient.post<{ is_following: boolean }>(
    ENDPOINTS.CATEGORY_FOLLOW(categoryId),
    cityId ? { city_id: cityId } : {},
  );
  return res.data!;
}

export async function fetchFollowStatus(
  categoryId: number,
): Promise<{ is_following: boolean }> {
  const res = await apiClient.get<{ is_following: boolean }>(
    ENDPOINTS.CATEGORY_FOLLOW_STATUS(categoryId),
  );
  return res.data!;
}

export interface FollowedCategory {
  id: number;
  category: { id: number; name_ar: string; icon: string | null };
  city: { id: number; name_ar: string } | null;
  created_at: string;
}

export async function fetchFollows(): Promise<FollowedCategory[]> {
  const res = await apiClient.get<FollowedCategory[]>(ENDPOINTS.FOLLOWS);
  return res.data ?? [];
}
