// ── Server-side fetchers — Sprint 18 ──────────────────────────────────────
// Used by Server Components for SSR data fetching (no Axios/client state).

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000/api';

interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
}

export interface AdServerData {
  id: number;
  title: string;
  description: string | null;
  price: number;
  currency: string;
  status: string;
  category: { id: number; name_ar: string; name_en: string; slug: string } | null;
  city: { id: number; name_ar: string; name_en: string } | null;
  region: { id: number; name_ar: string; name_en: string } | null;
  user: { id: number; name: string; avatar: string | null; phone: string | null } | null;
  images: { id: number; image_url: string; thumbnail_url: string; sort_order: number }[];
  field_values: { field_key: string; label_ar: string; value: string }[];
  views_count: number;
  is_boosted: boolean;
  boosted_until: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Fetch a single ad for SSR.
 * Uses native fetch with no-store to avoid stale cached data.
 */
export async function fetchAdServer(id: string | number): Promise<AdServerData | null> {
  try {
    const res = await fetch(`${API_BASE}/v1/ads/${id}`, {
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    });

    if (!res.ok) return null;

    const json: ApiResponse<AdServerData> = await res.json();
    return json.data ?? null;
  } catch {
    return null;
  }
}

/**
 * Fetch all active ad IDs for sitemap generation.
 */
export interface StaticPageData {
  id: number;
  slug: string;
  title_ar: string;
  title_en: string;
  content_ar: string;
  content_en: string;
  meta_description_ar: string | null;
  meta_description_en: string | null;
  is_published: boolean;
  updated_at: string;
}

/**
 * Fetch a published static page by slug for SSR.
 * Returns null when the page is not found or not published.
 */
export async function fetchStaticPage(slug: string): Promise<StaticPageData | null> {
  try {
    const res = await fetch(`${API_BASE}/v1/pages/${slug}`, {
      next: { revalidate: 300 }, // 5-minute ISR cache
      headers: { Accept: 'application/json' },
    });
    if (!res.ok) return null;
    const json: ApiResponse<StaticPageData> = await res.json();
    return json.data ?? null;
  } catch {
    return null;
  }
}

export async function fetchAdIdsForSitemap(): Promise<number[]> {
  try {
    const res = await fetch(`${API_BASE}/v1/ads?per_page=1000&fields=id`, {
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    });

    if (!res.ok) return [];

    const json = await res.json();
    const ads = json.data?.data || json.data || [];
    return ads.map((ad: { id: number }) => ad.id);
  } catch {
    return [];
  }
}
