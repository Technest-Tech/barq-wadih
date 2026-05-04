import apiClient from './client';
import ENDPOINTS from './endpoints';

export type District = {
  id: number;
  name_ar: string;
  name_en: string | null;
  slug: string;
  latitude: number | null;
  longitude: number | null;
  city_id: number;
  region_id: number;
};

/**
 * Fetch active districts for a city. An empty array signals the wizard
 * to fall back to a free-text input.
 */
export async function fetchDistrictsByCity(cityId: number): Promise<District[]> {
  const res = await apiClient.get<District[]>(ENDPOINTS.CITY_DISTRICTS(cityId));
  return res.data ?? [];
}
