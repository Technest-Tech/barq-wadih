import { MetadataRoute } from 'next';
import { fetchAdIdsForSitemap } from '@/lib/api/server-fetchers';

const BASE_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://barqwadih.com';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // Static pages.
  // localePrefix 'as-needed' + defaultLocale 'ar' => the Arabic URL is the
  // UNPREFIXED one (/, /ads/{id}); the /ar/* variants 307-redirect. The sitemap
  // must list the real, non-redirecting URLs, or Search Console reports them as
  // "Page with redirect".
  const staticPages: MetadataRoute.Sitemap = [
    {
      url: BASE_URL,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1.0,
      alternates: {
        languages: { ar: BASE_URL, en: `${BASE_URL}/en` },
      },
    },
  ];

  // Dynamic ad pages
  let adPages: MetadataRoute.Sitemap = [];
  try {
    const adIds = await fetchAdIdsForSitemap();
    adPages = adIds.map((id) => ({
      url: `${BASE_URL}/ads/${id}`,
      lastModified: new Date(),
      changeFrequency: 'weekly' as const,
      priority: 0.8,
      alternates: {
        languages: { ar: `${BASE_URL}/ads/${id}`, en: `${BASE_URL}/en/ads/${id}` },
      },
    }));
  } catch {
    // Graceful: return static pages only if API unreachable
  }

  return [...staticPages, ...adPages];
}
