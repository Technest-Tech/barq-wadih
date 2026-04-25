// ── Admin Analytics API — Sprint 16 ───────────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ───────────────────────────────────────────────────────────────────

export interface RevenuePoint {
  label: string;
  date: string;
  revenue: number;
}

export interface RevenueData {
  period: string;
  grouping: string;
  series: RevenuePoint[];
  total_revenue: number;
  total_transactions: number;
}

export interface CityDistribution {
  city_id: number;
  city_name: string;
  region_name: string;
  ad_count: number;
}

export interface SearchTermItem {
  query: string;
  search_count: number;
  avg_results: number;
  last_searched: string;
}

export interface DailyVolume {
  date: string;
  label: string;
  count: number;
}

export interface PlatformBreakdown {
  platform: string;
  count: number;
}

export interface SearchTermsData {
  terms: SearchTermItem[];
  daily_volume: DailyVolume[];
  platforms: PlatformBreakdown[];
  total_searches: number;
}

export interface ZeroResultItem {
  query: string;
  search_count: number;
  last_searched: string;
}

export interface ZeroResultsData {
  terms: ZeroResultItem[];
  total_zero: number;
}

// ── API Functions ───────────────────────────────────────────────────────────

export async function fetchRevenueAnalytics(period: string = '30d'): Promise<RevenueData> {
  const res = await apiClient.get<RevenueData>(`${ENDPOINTS.ADMIN_ANALYTICS_REVENUE}?period=${period}`);
  return res.data;
}

export async function fetchAdsByCity(): Promise<CityDistribution[]> {
  const res = await apiClient.get<CityDistribution[]>(ENDPOINTS.ADMIN_ANALYTICS_ADS_BY_CITY);
  return res.data;
}

export async function fetchTopSearchTerms(days: number = 90): Promise<SearchTermsData> {
  const res = await apiClient.get<SearchTermsData>(`${ENDPOINTS.ADMIN_ANALYTICS_SEARCH_TERMS}?days=${days}`);
  return res.data;
}

export async function fetchZeroResultQueries(days: number = 90): Promise<ZeroResultsData> {
  const res = await apiClient.get<ZeroResultsData>(`${ENDPOINTS.ADMIN_ANALYTICS_ZERO_RESULTS}?days=${days}`);
  return res.data;
}
