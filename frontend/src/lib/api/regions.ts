// ── Region & City API types & fetchers ───────────────────────────────────────

import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ────────────────────────────────────────────────────────────────────

export type Region = {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
  sort_order: number;
  cities_count: number;
};

export type City = {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
  latitude: number | null;
  longitude: number | null;
  ads_count: number;
  /** Number of seeded districts. 0 → wizard falls back to free-text input. */
  districts_count: number | null;
  region?: Pick<Region, 'id' | 'name_ar' | 'name_en' | 'slug'>;
};

// ── Fetchers ─────────────────────────────────────────────────────────────────

/**
 * Fetch all 13 Saudi regions from GET /api/v1/regions.
 */
export async function fetchRegions(): Promise<Region[]> {
  const response = await apiClient.get<Region[]>(ENDPOINTS.REGIONS);
  return response.data;
}

/**
 * Fetch all active cities for a region from GET /api/v1/regions/{slug}/cities.
 */
export async function fetchCities(regionSlug: string): Promise<City[]> {
  const endpoint = ENDPOINTS.REGION_CITIES(regionSlug);
  const response = await apiClient.get<City[]>(endpoint);
  return response.data;
}

/**
 * Fetch ALL cities across all regions from GET /api/v1/cities.
 */
export async function fetchAllCities(): Promise<City[]> {
  const response = await apiClient.get<City[]>(ENDPOINTS.ALL_CITIES);
  return response.data;
}
