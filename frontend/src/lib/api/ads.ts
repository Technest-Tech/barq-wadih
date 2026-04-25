import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { PaginatedResponse, ApiResponse } from './types';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface AdImage {
  id: number;
  image_url: string;
  thumbnail_url: string;
  sort_order: number;
  width: number;
  height: number;
}

export interface CategoryField {
  id: number;
  field_key: string;
  label_ar: string;
  label_en: string;
  field_type: 'text' | 'number' | 'select' | 'multi_select' | 'year' | 'boolean';
  options: string[] | null;
  is_required: boolean;
  is_filterable: boolean;
  sort_order: number;
  placeholder_ar: string | null;
  placeholder_en: string | null;
}

export interface AdListItem {
  id: number;
  user_id: number;
  title: string;
  price: string | null;
  is_negotiable: boolean;
  is_free: boolean;
  status: string;
  status_label: string;
  primary_image: AdImage | null;
  category: { id: number; name_ar: string; slug: string; icon: string | null } | null;
  city: { id: number; name_ar: string } | null;
  region: { id: number; name_ar: string } | null;
  user?: { id: number; name: string; avatar: string | null } | null;
  is_boosted: boolean;
  boosted_until: string | null;
  published_at: string | null;
  created_at: string;
}

export interface AdFieldValue {
  field_key: string;
  label_ar: string;
  label_en: string;
  field_type: string;
  value: unknown;
}

export interface Ad extends AdListItem {
  description: string;
  moderation_status: string;
  images: AdImage[];
  field_values: AdFieldValue[];
  user: { id: number; name: string; avatar: string | null } | null;
  contact_phone: string;
  contact_whatsapp: string | null;
  views_count: number;
  favorites_count: number;
  commission_amount: string | null;
  expires_at: string | null;
  updated_at: string;
  // Sprint 13: Boost eligibility (owner-only, null for non-owners)
  can_boost?: boolean | null;
  can_refresh?: boolean | null;
  next_refresh_at?: string | null;
}

export interface AdsFilters {
  category_id?: number;
  city_id?: number;
  region_id?: number;
  price_min?: number;
  price_max?: number;
  q?: string;
  sort?: 'newest' | 'price_asc' | 'price_desc';
  page?: number;
}

// ── API functions ─────────────────────────────────────────────────────────────

/**
 * Fetch paginated ad feed with optional filters.
 */
export async function fetchAds(filters: AdsFilters = {}): Promise<PaginatedResponse<AdListItem>> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([k, v]) => {
    if (v !== undefined && v !== null) params.set(k, String(v));
  });
  const qs = params.toString() ? `?${params.toString()}` : '';
  const res = await apiClient.getPaginated<AdListItem>(`${ENDPOINTS.ADS}${qs}`);
  return res;
}

/**
 * Fetch a single ad by ID.
 */
export async function fetchAd(id: number): Promise<Ad> {
  const res = await apiClient.get<Ad>(ENDPOINTS.AD_DETAIL(id));
  return res.data!;
}

/**
 * Fetch the current user's ads.
 */
export async function fetchMyAds(): Promise<PaginatedResponse<AdListItem>> {
  return apiClient.getPaginated<AdListItem>(ENDPOINTS.MY_ADS);
}

/**
 * Create a new ad using multipart/form-data.
 */
export async function createAd(formData: FormData): Promise<Ad> {
  const res = await apiClient.postFormData<Ad>(ENDPOINTS.ADS, formData);
  return res.data!;
}

/**
 * Update an existing ad using multipart/form-data (PATCH).
 */
export async function updateAd(id: number, formData: FormData): Promise<Ad> {
  const res = await apiClient.postFormData<Ad>(ENDPOINTS.AD_UPDATE(id), formData, 'PATCH');
  return res.data!;
}

/**
 * Delete an ad by ID.
 */
export async function deleteAd(id: number): Promise<void> {
  await apiClient.delete(ENDPOINTS.AD_DELETE(id));
}

/**
 * Mark an ad as sold.
 */
export async function markAdSold(id: number): Promise<AdListItem> {
  const res = await apiClient.post<AdListItem>(ENDPOINTS.AD_MARK_SOLD(id), {});
  return res.data!;
}

/**
 * Fetch dynamic fields for a category.
 */
export async function fetchCategoryFields(categoryId: number): Promise<CategoryField[]> {
  const res = await apiClient.get<CategoryField[]>(ENDPOINTS.CATEGORY_FIELDS(categoryId));
  return res.data ?? [];
}

// ── Commission Preview ────────────────────────────────────────────────────────

export interface CommissionPreview {
  price: number;
  is_free: boolean;
  commission_amount: number;
  commission_rate: string;
  minimum_commission: number;
  note: string;
}

/**
 * Fetch commission preview for a given price.
 */
export async function fetchCommissionPreview(price: number, isFree: boolean = false): Promise<CommissionPreview> {
  const params = new URLSearchParams({ price: String(price), is_free: isFree ? '1' : '0' });
  const res = await apiClient.get<CommissionPreview>(`${ENDPOINTS.COMMISSION_PREVIEW}?${params.toString()}`);
  return res.data!;
}

// ── Search (Sprint 7) ─────────────────────────────────────────────────────────

export interface SearchFilters {
  q?: string;
  category_id?: number;
  city_id?: number;
  region_id?: number;
  price_min?: number;
  price_max?: number;
  is_free?: boolean;
  sort?: 'newest' | 'price_asc' | 'price_desc' | 'relevance';
  page?: number;
}

/**
 * Full-text search with Meilisearch (falls back to MySQL LIKE on server).
 * Logs the search query for analytics via SearchLog.
 */
export async function searchAds(filters: SearchFilters = {}): Promise<PaginatedResponse<AdListItem>> {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') {
      params.set(k, String(v));
    }
  });
  const qs = params.toString() ? `?${params.toString()}` : '';
  return apiClient.getPaginated<AdListItem>(`${ENDPOINTS.SEARCH}${qs}`);
}
