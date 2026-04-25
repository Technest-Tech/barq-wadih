import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { ApiResponse, PaginatedResponse } from './types';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface RatingRater {
  id: number;
  name: string;
  avatar: string | null;
}

export interface Rating {
  id: number;
  stars: number;
  comment: string | null;
  is_approved: boolean;
  rater: RatingRater;
  ad: { id: number; title: string } | null;
  created_at: string;
}

export interface RatingSummary {
  avg_rating: number;
  rating_count: number;
  distribution: Record<1 | 2 | 3 | 4 | 5, number>;
}

export interface SubmitRatingPayload {
  stars: number;
  comment?: string;
  pledge_accepted: true;
}

// ── API functions ─────────────────────────────────────────────────────────────

export async function fetchAdRatings(
  adId: number,
  page = 1,
): Promise<PaginatedResponse<Rating>> {
  return apiClient.getPaginated<Rating>(
    `${ENDPOINTS.AD_RATINGS(adId)}?page=${page}`,
  );
}

export async function fetchUserRatings(
  userId: number,
  page = 1,
): Promise<PaginatedResponse<Rating>> {
  return apiClient.getPaginated<Rating>(
    `${ENDPOINTS.USER_RATINGS(userId)}?page=${page}`,
  );
}

export async function fetchUserRatingSummary(
  userId: number,
): Promise<RatingSummary> {
  const res = await apiClient.get<RatingSummary>(
    ENDPOINTS.USER_RATING_SUMMARY(userId),
  );
  return res.data!;
}

export async function submitRating(
  adId: number,
  payload: SubmitRatingPayload,
): Promise<Rating> {
  const res = await apiClient.post<Rating>(ENDPOINTS.AD_RATE(adId), payload);
  return res.data!;
}

export async function deleteRating(ratingId: number): Promise<void> {
  await apiClient.delete(ENDPOINTS.DELETE_RATING(ratingId));
}
