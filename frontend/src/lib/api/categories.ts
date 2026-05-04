// ── Category API types & fetchers ───────────────────────────────────────────

import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ────────────────────────────────────────────────────────────────────

export type CategoryChild = {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
  icon: string | null;
  image: string | null;
  description_ar: string | null;
  description_en: string | null;
  sort_order: number;
  is_active: boolean;
  is_free: boolean;
  ads_count: number;
  fields_count: number;
  /** Per-category publish fee (added in the post-ad wizard sprint). */
  publish_fee_individual: string | number | null;
  publish_fee_dealer: string | number | null;
  fee_deductible_from_commission: boolean;
};

export type Category = CategoryChild & {
  children: CategoryChild[];
};

// ── Fetchers ─────────────────────────────────────────────────────────────────

/**
 * Fetch the full hierarchical category tree from GET /api/v1/categories.
 * Returns all active top-level categories with their active children.
 */
export async function fetchCategories(): Promise<Category[]> {
  const response = await apiClient.get<Category[]>(ENDPOINTS.CATEGORIES);
  return response.data.filter(cat => cat.slug !== 'real-estate');
}
