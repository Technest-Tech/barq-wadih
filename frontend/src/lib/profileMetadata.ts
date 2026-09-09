// ── Seller profile metadata ───────────────────────────────────────────────────
// Shared by the two public profile routes — /@{handle} and /users/{id} — so a
// link shared to WhatsApp, X or Telegram previews identically whichever one
// was copied.

import type { Metadata } from 'next';
import type { SellerProfile } from './api/users';

/** Handles are generated server-side from a transliterated name: [a-z0-9_]. */
export const HANDLE_PATTERN = /^[a-z0-9_]{1,30}$/;

/**
 * Path the profile should be indexed under. Prefers the @handle, falling back
 * to the numeric id for the rare row that has no handle yet.
 *
 * localePrefix is 'as-needed' with defaultLocale 'ar', so Arabic URLs are
 * unprefixed — /ar/... 307-redirects, and canonicals must not point at a
 * redirect.
 */
export function sellerProfilePath(profile: SellerProfile, locale: string): string {
  const path = profile.username ? `/@${profile.username}` : `/users/${profile.id}`;

  return locale === 'ar' ? path : `/${locale}${path}`;
}

export function buildSellerMetadata(profile: SellerProfile, locale: string): Metadata {
  const isArabic = locale === 'ar';
  const siteName = isArabic ? 'برق واضح' : 'Barq Wadih';

  // The locale layout applies a "%s | برق واضح" title template, so the page
  // title stays bare — but og:/twitter: titles bypass the template and need
  // the site name spelled out.
  const socialTitle = `${profile.name} | ${siteName}`;

  const description = isArabic
    ? `الصفحة الشخصية لـ ${profile.name} في برق واضح — ${profile.active_ads_count} إعلان نشط. تصفّح عروضه وتواصل معه مباشرة.`
    : `${profile.name} on Barq Wadih — ${profile.active_ads_count} active listings. Browse their offers and get in touch.`;

  // Cover images are wide enough for a large card; a square avatar reads far
  // better in the small one.
  const cover = profile.cover_image ?? null;
  const image = cover ?? profile.avatar ?? null;

  const arPath = profile.username ? `/@${profile.username}` : `/users/${profile.id}`;

  return {
    title: profile.name,
    description,
    openGraph: {
      title: socialTitle,
      description,
      type: 'profile',
      locale: isArabic ? 'ar_SA' : 'en_US',
      siteName,
      url: sellerProfilePath(profile, locale),
      ...(image ? { images: [{ url: image, alt: profile.name }] } : {}),
    },
    twitter: {
      card: cover ? 'summary_large_image' : 'summary',
      title: socialTitle,
      description,
      ...(image ? { images: [image] } : {}),
    },
    alternates: {
      canonical: sellerProfilePath(profile, locale),
      languages: {
        ar: arPath,
        en: `/en${arPath}`,
      },
    },
  };
}
