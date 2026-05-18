// ── Admin API module — Sprint 14 ──────────────────────────────────────────
import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ───────────────────────────────────────────────────────────────
export interface DashboardStats {
  users: {
    total: number;
    active: number;
    verified: number;
    dealers: number;
    new_today: number;
    new_this_week: number;
    new_this_month: number;
    new_prev_month: number;
    by_role: { role: string; label: string; count: number }[];
    weekly_registrations: { week: string; count: number }[];
  };
  ads: {
    total: number;
    active: number;
    new_today: number;
    new_this_week: number;
    by_status: { status: string; label: string; count: number }[];
  };
  revenue: {
    total: number;
    this_month: number;
    prev_month: number;
    pending_commissions: number;
    monthly: { month: string; revenue: number }[];
  };
  banners: { active: number };
  reports: { pending: number };
  recent_ads: RecentAd[];
}

export interface RecentAd {
  id: number;
  title: string;
  price: number;
  status: string;
  status_label: string;
  user: { id: number; name: string; avatar_url: string | null } | null;
  category: { id: number; name_ar: string; name_en: string } | null;
  city: { id: number; name_ar: string; name_en: string } | null;
  created_at: string;
}

export interface AdminUser {
  id: number;
  name: string;
  email: string | null;
  phone: string | null;
  avatar_url: string | null;
  bio: string | null;
  role: string;
  role_label: string;
  locale: string;
  is_verified: boolean;
  is_dealer: boolean;
  is_active: boolean;
  avg_rating: string;
  rating_count: number;
  total_ads_count: number;
  commissions_paid_count: number;
  commissions_due_count: number;
  phone_verified_at: string | null;
  email_verified_at: string | null;
  last_active_at: string | null;
  region: { id: number; name_ar: string; name_en: string } | null;
  city: { id: number; name_ar: string; name_en: string } | null;
  created_at: string;
}

export interface AdminUserDetail extends AdminUser {
  firebase_uid: string | null;
  updated_at: string;
  ads: UserAd[];
  commission_payments: UserPayment[];
  ratings_received: UserRating[];
  devices_count: number;
}

export interface UserAd {
  id: number;
  title: string;
  price: number;
  status: string;
  status_label: string;
  category: { id: number; name_ar: string } | null;
  city: { id: number; name_ar: string } | null;
  views_count: number;
  created_at: string;
  expires_at: string | null;
}

export interface UserPayment {
  id: number;
  amount: number;
  status: string;
  payment_method: string | null;
  ad_id: number | null;
  paid_at: string | null;
  created_at: string;
}

export interface UserRating {
  id: number;
  score: number;
  comment: string | null;
  rater: { id: number; name: string } | null;
  created_at: string;
}

export interface AdminUserFilters {
  q?: string;
  role?: string;
  is_active?: string;
  is_verified?: string;
  is_dealer?: string;
  region_id?: string;
  city_id?: string;
  sort?: string;
  dir?: string;
  page?: number;
  per_page?: number;
}

// ── API Functions ───────────────────────────────────────────────────────
export async function fetchDashboardStats(): Promise<DashboardStats> {
  const res = await apiClient.get<DashboardStats>(ENDPOINTS.ADMIN_DASHBOARD_STATS);
  return res.data;
}

export async function fetchAdminUsers(filters: AdminUserFilters = {}) {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== '') {
      params.append(key, String(value));
    }
  });
  const queryString = params.toString();
  const endpoint = `${ENDPOINTS.ADMIN_USERS}${queryString ? `?${queryString}` : ''}`;
  return apiClient.getPaginated<AdminUser>(endpoint);
}

export async function fetchAdminUser(id: number): Promise<AdminUserDetail> {
  const res = await apiClient.get<AdminUserDetail>(ENDPOINTS.ADMIN_USER_DETAIL(id));
  return res.data;
}

export async function updateUserStatus(id: number, isActive: boolean) {
  return apiClient.patch<AdminUser>(ENDPOINTS.ADMIN_USER_STATUS(id), { is_active: isActive });
}

export async function updateUserRole(id: number, role: string) {
  return apiClient.patch<AdminUser>(ENDPOINTS.ADMIN_USER_ROLE(id), { role });
}

// ── Sprint 15: Types ────────────────────────────────────────────────────

export interface AdminAd {
  id: number;
  title: string;
  description: string;
  price: number;
  is_negotiable: boolean;
  is_free: boolean;
  status: string;
  status_label: string;
  moderation_status: string;
  moderation_label: string;
  moderation_note: string | null;
  commission_amount: number;
  commission_status: string | null;
  contact_phone: string | null;
  contact_whatsapp: string | null;
  views_count: number;
  favorites_count: number;
  chats_count: number;
  reports_count: number;
  is_boosted: boolean;
  boosted_until: string | null;
  user: { id: number; name: string; avatar_url: string | null; phone: string | null; email: string | null; is_verified: boolean; role: string } | null;
  category: { id: number; name_ar: string; name_en: string } | null;
  city: { id: number; name_ar: string; name_en: string } | null;
  region: { id: number; name_ar: string; name_en: string } | null;
  images: { id: number; url: string; sort_order: number }[];
  field_values?: { field_key: string; label_ar: string; value: string }[];
  reports?: AdminAdReport[];
  published_at: string | null;
  expires_at: string | null;
  created_at: string;
  deleted_at: string | null;
}

export interface AdminAdReport {
  id: number;
  reason: string;
  reason_label: string;
  description: string | null;
  status: string;
  status_label: string;
  reporter: { id: number; name: string } | null;
  admin_note: string | null;
  created_at: string;
}

export interface AdminAdFilters {
  q?: string;
  status?: string;
  moderation_status?: string;
  category_id?: string;
  city_id?: string;
  region_id?: string;
  user_id?: string;
  date_from?: string;
  date_to?: string;
  has_reports?: string;
  sort?: string;
  dir?: string;
  page?: number;
  per_page?: number;
}

export interface AdminReport {
  id: number;
  reason: string;
  reason_label: string;
  description: string | null;
  status: string;
  status_label: string;
  admin_action: string | null;
  admin_action_label: string | null;
  admin_note: string | null;
  resolved_at: string | null;
  reporter: { id: number; name: string; avatar_url: string | null } | null;
  ad: {
    id: number;
    title: string;
    price: number;
    status: string;
    status_label: string;
    primary_image: string | null;
    category: { id: number; name_ar: string } | null;
    user: { id: number; name: string; avatar_url: string | null } | null;
    created_at: string;
  } | null;
  admin: { id: number; name: string } | null;
  created_at: string;
}

export interface AdminCategory {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
  icon: string | null;
  image: string | null;
  parent_id: number | null;
  description_ar: string | null;
  description_en: string | null;
  commission_rate: string | null;
  publish_fee_individual: string | null;
  publish_fee_dealer: string | null;
  fee_deductible_from_commission: boolean;
  deferred_commission_individual: string | null;
  deferred_commission_dealer: string | null;
  commission_trigger: 'after_sale' | 'after_90_days';
  is_free: boolean;
  is_active: boolean;
  sort_order: number;
  ads_count: number;
  fields_count: number;
  children?: AdminCategory[];
}

export interface AdminCategoryField {
  id: number;
  category_id: number;
  field_key: string;
  label_ar: string;
  label_en: string;
  field_type: string;
  options: string[] | null;
  is_required: boolean;
  is_filterable: boolean;
  sort_order: number;
}

export interface AdminRegion {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
  is_active: boolean;
  sort_order: number;
  cities_count: number;
  ads_count: number;
  cities: AdminCity[];
}

export interface AdminCity {
  id: number;
  name_ar: string;
  name_en: string;
  slug: string;
  latitude: number | null;
  longitude: number | null;
  is_active: boolean;
  sort_order: number;
  ads_count: number;
}

export interface AdminStaticPage {
  id: number;
  slug: string;
  title_ar: string;
  title_en: string;
  content_ar: string;
  content_en: string;
  meta_description_ar: string | null;
  meta_description_en: string | null;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

// ── Sprint 15: API Functions ────────────────────────────────────────────

// Helper to build query strings
function buildQuery(filters: Record<string, unknown>): string {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== '') params.append(key, String(value));
  });
  const qs = params.toString();
  return qs ? `?${qs}` : '';
}

// ── Ads ─────────────────────────────────────────────────────────────────
export async function fetchAdminAds(filters: AdminAdFilters = {}) {
  return apiClient.getPaginated<AdminAd>(`${ENDPOINTS.ADMIN_ADS}${buildQuery(filters as Record<string, unknown>)}`);
}

export async function fetchAdminAd(id: number): Promise<AdminAd> {
  const res = await apiClient.get<AdminAd>(ENDPOINTS.ADMIN_AD_DETAIL(id));
  return res.data;
}

export async function approveAd(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_AD_APPROVE(id), {});
}

export async function rejectAd(id: number, rejection_reason: string) {
  return apiClient.post(ENDPOINTS.ADMIN_AD_REJECT(id), { rejection_reason });
}

export async function deleteAd(id: number, admin_note?: string) {
  return apiClient.delete(`${ENDPOINTS.ADMIN_AD_DETAIL(id)}${admin_note ? `?admin_note=${encodeURIComponent(admin_note)}` : ''}`);
}

export async function restoreAd(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_AD_RESTORE(id), {});
}

// ── Reports ─────────────────────────────────────────────────────────────
export async function fetchAdminReports(filters: Record<string, unknown> = {}) {
  return apiClient.getPaginated<AdminReport>(`${ENDPOINTS.ADMIN_REPORTS}${buildQuery(filters)}`);
}

export async function fetchAdminReport(id: number): Promise<AdminReport> {
  const res = await apiClient.get<AdminReport>(ENDPOINTS.ADMIN_REPORT_DETAIL(id));
  return res.data;
}

export async function resolveReport(id: number, data: { admin_action: string; admin_note?: string }) {
  return apiClient.post(ENDPOINTS.ADMIN_REPORT_RESOLVE(id), data);
}

export async function dismissReport(id: number, admin_note?: string) {
  return apiClient.post(ENDPOINTS.ADMIN_REPORT_DISMISS(id), { admin_note });
}

// ── Categories ──────────────────────────────────────────────────────────
export async function fetchAdminCategories(): Promise<AdminCategory[]> {
  const res = await apiClient.get<AdminCategory[]>(ENDPOINTS.ADMIN_CATEGORIES);
  return res.data;
}

export async function createCategory(data: FormData | Record<string, unknown>) {
  if (data instanceof FormData) {
    return apiClient.postFormData<AdminCategory>(ENDPOINTS.ADMIN_CATEGORIES, data);
  }
  return apiClient.post<AdminCategory>(ENDPOINTS.ADMIN_CATEGORIES, data);
}

export async function updateCategory(id: number, data: FormData | Record<string, unknown>) {
  if (data instanceof FormData) {
    data.append('_method', 'PUT');
    return apiClient.postFormData<AdminCategory>(ENDPOINTS.ADMIN_CATEGORY_DETAIL(id), data);
  }
  return apiClient.put<AdminCategory>(ENDPOINTS.ADMIN_CATEGORY_DETAIL(id), data);
}

export async function toggleCategory(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_CATEGORY_TOGGLE(id), {});
}

export async function reorderCategories(items: { id: number; sort_order: number }[]) {
  return apiClient.post(ENDPOINTS.ADMIN_CATEGORIES_REORDER, { items });
}

export async function fetchCategoryFields(categoryId: number): Promise<AdminCategoryField[]> {
  const res = await apiClient.get<AdminCategoryField[]>(ENDPOINTS.ADMIN_CATEGORY_FIELDS(categoryId));
  return res.data;
}

export async function createCategoryField(categoryId: number, data: Record<string, unknown>) {
  return apiClient.post(ENDPOINTS.ADMIN_CATEGORY_FIELDS(categoryId), data);
}

export async function updateCategoryField(fieldId: number, data: Record<string, unknown>) {
  return apiClient.put(ENDPOINTS.ADMIN_FIELD_DETAIL(fieldId), data);
}

export async function deleteCategoryField(fieldId: number) {
  return apiClient.delete(ENDPOINTS.ADMIN_FIELD_DETAIL(fieldId));
}

// ── Regions ─────────────────────────────────────────────────────────────
export async function fetchAdminRegions(): Promise<AdminRegion[]> {
  const res = await apiClient.get<AdminRegion[]>(ENDPOINTS.ADMIN_REGIONS);
  return res.data;
}

export async function toggleRegion(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_REGION_TOGGLE(id), {});
}

export async function toggleCity(id: number) {
  return apiClient.post(ENDPOINTS.ADMIN_CITY_TOGGLE(id), {});
}

export async function updateCity(id: number, data: Record<string, unknown>) {
  return apiClient.put(ENDPOINTS.ADMIN_CITY_UPDATE(id), data);
}

// ── Static Pages ────────────────────────────────────────────────────────
export async function fetchAdminPages(): Promise<AdminStaticPage[]> {
  const res = await apiClient.get<AdminStaticPage[]>(ENDPOINTS.ADMIN_PAGES);
  return res.data;
}

export async function fetchAdminPage(id: number): Promise<AdminStaticPage> {
  const res = await apiClient.get<AdminStaticPage>(ENDPOINTS.ADMIN_PAGE_DETAIL(id));
  return res.data;
}

export async function createPage(data: Record<string, unknown>) {
  return apiClient.post<AdminStaticPage>(ENDPOINTS.ADMIN_PAGES, data);
}

export async function updatePage(id: number, data: Record<string, unknown>) {
  return apiClient.put<AdminStaticPage>(ENDPOINTS.ADMIN_PAGE_DETAIL(id), data);
}

export async function deletePage(id: number) {
  return apiClient.delete(ENDPOINTS.ADMIN_PAGE_DETAIL(id));
}
