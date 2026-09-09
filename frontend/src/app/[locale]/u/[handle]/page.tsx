// ── Public profile by @handle — barqwadih.com/@ahmd_aamr ──────────────────────
//
// Reached only through the rewrite in src/proxy.ts: the visible URL is
// /@{handle}, but a folder named "@handle" would be read as a parallel-route
// slot, so the route itself lives here under /u. The handle arrives without
// its "@" already stripped.

import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import SellerProfileClient from '@/components/profile/SellerProfileClient';
import { fetchSellerProfileServer } from '@/lib/api/server-fetchers';
import { buildSellerMetadata, HANDLE_PATTERN } from '@/lib/profileMetadata';

type Props = {
  params: Promise<{ handle: string; locale: string }>;
};

/** Reject anything the proxy's own pattern wouldn't have produced. */
function parseHandle(raw: string): string | null {
  const handle = decodeURIComponent(raw).toLowerCase();

  return HANDLE_PATTERN.test(handle) ? handle : null;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { handle: raw, locale } = await params;
  const handle = parseHandle(raw);
  const isArabic = locale === 'ar';

  if (!handle) {
    return { title: isArabic ? 'صفحة غير موجودة' : 'Page not found' };
  }

  const profile = await fetchSellerProfileServer(`@${handle}`);

  if (!profile) {
    return { title: isArabic ? 'الحساب غير موجود' : 'Account not found' };
  }

  return buildSellerMetadata(profile, locale);
}

function ProfileJsonLd({ name, url, image }: { name: string; url: string; image: string | null }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'ProfilePage',
    mainEntity: {
      '@type': 'Person',
      name,
      url,
      ...(image ? { image } : {}),
    },
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}

export default async function HandleProfilePage({ params }: Props) {
  const { handle: raw } = await params;
  const handle = parseHandle(raw);

  if (!handle) {
    notFound();
  }

  const profile = await fetchSellerProfileServer(`@${handle}`);

  if (!profile) {
    notFound();
  }

  return (
    <>
      <ProfileJsonLd
        name={profile.name}
        url={profile.profile_url ?? ''}
        image={profile.avatar}
      />
      <SellerProfileClient userId={profile.id} initialProfile={profile} />
    </>
  );
}
