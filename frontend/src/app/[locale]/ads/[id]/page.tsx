import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { fetchAdServer, type AdServerData } from '@/lib/api/server-fetchers';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import AdDetailClient from './AdDetailClient';
import styles from './page.module.css';

// ── Types ─────────────────────────────────────────────────────────────────────

type Props = {
  params: Promise<{ id: string; locale: string }>;
};

// ── Dynamic Metadata — SEO + Open Graph ───────────────────────────────────────

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id, locale } = await params;
  const ad = await fetchAdServer(id);
  const isArabic = locale === 'ar';

  if (!ad) {
    return { title: isArabic ? 'إعلان غير موجود' : 'Ad not found' };
  }

  const priceText = ad.price ? `${Number(ad.price).toLocaleString()} ر.س` : 'مجاني';
  const cityName = ad.city?.name_ar ?? '';
  const description = ad.description
    ? ad.description.slice(0, 160)
    : `${ad.title} - ${priceText} - ${cityName}`;

  const ogImage = ad.images?.[0]?.image_url ?? undefined;

  return {
    title: ad.title,
    description,
    openGraph: {
      title: ad.title,
      description,
      type: 'website',
      locale: isArabic ? 'ar_SA' : 'en_US',
      siteName: isArabic ? 'برق واضح' : 'Barq Wadih',
      ...(ogImage ? { images: [{ url: ogImage, width: 1200, height: 630, alt: ad.title }] } : {}),
    },
    twitter: {
      card: 'summary_large_image',
      title: ad.title,
      description,
      ...(ogImage ? { images: [ogImage] } : {}),
    },
    alternates: {
      // localePrefix is 'as-needed' with defaultLocale 'ar', so the Arabic URL
      // is UNPREFIXED (/ads/{id}); /ar/ads/{id} 307-redirects to it. Canonicals
      // and hreflang must use the real, non-redirecting URLs.
      canonical: isArabic ? `/ads/${ad.id}` : `/${locale}/ads/${ad.id}`,
      languages: {
        ar: `/ads/${ad.id}`,
        en: `/en/ads/${ad.id}`,
      },
    },
  };
}

// ── JSON-LD Structured Data ───────────────────────────────────────────────────

function AdJsonLd({ ad }: { ad: AdServerData }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: ad.title,
    description: ad.description ?? undefined,
    image: ad.images?.map((img) => img.image_url) ?? [],
    offers: {
      '@type': 'Offer',
      price: ad.price?.toString() ?? '0',
      priceCurrency: 'SAR',
      availability: ad.status === 'active'
        ? 'https://schema.org/InStock'
        : 'https://schema.org/SoldOut',
      seller: ad.user ? { '@type': 'Person', name: ad.user.name } : undefined,
    },
    ...(ad.city ? {
      contentLocation: {
        '@type': 'Place',
        name: ad.city.name_ar,
        address: {
          '@type': 'PostalAddress',
          addressLocality: ad.city.name_ar,
          addressRegion: ad.region?.name_ar,
          addressCountry: 'SA',
        },
      },
    } : {}),
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}

// ── Server Component Page ─────────────────────────────────────────────────────

export default async function AdDetailPage({ params }: Props) {
  const { id } = await params;
  const ad = await fetchAdServer(id);

  // Ad doesn't exist (deleted/expired). Return a real HTTP 404 via notFound()
  // instead of rendering a 404-looking page with a 200 status — the latter is
  // what Google reported as "Soft 404" in Search Console.
  if (!ad) {
    notFound();
  }

  // Map server data to client Ad type (image field name mapping is no longer necessary since the API matches)
  const clientAd = {
    ...ad,
    images: ad.images.map((img) => ({
      ...img,
      image_url: img.image_url,
      thumbnail_url: img.thumbnail_url,
    })),
  };

  return (
    <>
      <AdJsonLd ad={ad} />
      <Header />
      <main className={styles.main}>
        {/* @ts-expect-error - Server ad shape maps to client ad props */}
        <AdDetailClient ad={clientAd} />
      </main>
      <Footer />
    </>
  );
}
