import { MetadataRoute } from 'next';
import { fetchAdIdsForSitemap } from '@/lib/api/server-fetchers';

const BASE_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://barqwadih.com';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // Static pages
  const staticPages: MetadataRoute.Sitemap = [
    {
      url: `${BASE_URL}/ar`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1.0,
      alternates: {
        languages: { ar: `${BASE_URL}/ar`, en: `${BASE_URL}/en` },
      },
    },
    {
      url: `${BASE_URL}/ar/search`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.9,
      alternates: {
        languages: { ar: `${BASE_URL}/ar/search`, en: `${BASE_URL}/en/search` },
      },
    },
  ];

  // Dynamic ad pages
  let adPages: MetadataRoute.Sitemap = [];
  try {
    const adIds = await fetchAdIdsForSitemap();
    adPages = adIds.map((id) => ({
      url: `${BASE_URL}/ar/ads/${id}`,
      lastModified: new Date(),
      changeFrequency: 'weekly' as const,
      priority: 0.8,
      alternates: {
        languages: { ar: `${BASE_URL}/ar/ads/${id}`, en: `${BASE_URL}/en/ads/${id}` },
      },
    }));
  } catch {
    // Graceful: return static pages only if API unreachable
  }

  return [...staticPages, ...adPages];
}
