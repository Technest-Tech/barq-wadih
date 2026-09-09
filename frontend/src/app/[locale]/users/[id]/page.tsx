// ── Public profile by numeric id — barqwadih.com/users/42 ─────────────────────
//
// Kept alongside the newer /@{handle} route because links to it are already in
// the wild (and the mobile app's older builds still build them). It renders the
// same profile, but canonicalises to the @handle so both don't get indexed.

import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import SellerProfileClient from '@/components/profile/SellerProfileClient';
import { fetchSellerProfileServer } from '@/lib/api/server-fetchers';
import { buildSellerMetadata } from '@/lib/profileMetadata';

type Props = {
  params: Promise<{ id: string; locale: string }>;
};

/** Only a plain positive integer is a valid id — no "42abc", no "-1". */
function parseUserId(raw: string): number | null {
  return /^\d+$/.test(raw) ? Number(raw) : null;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id, locale } = await params;
  const userId = parseUserId(id);
  const isArabic = locale === 'ar';

  if (userId === null) {
    return { title: isArabic ? 'صفحة غير موجودة' : 'Page not found' };
  }

  const profile = await fetchSellerProfileServer(String(userId));

  if (!profile) {
    return { title: isArabic ? 'الحساب غير موجود' : 'Account not found' };
  }

  return buildSellerMetadata(profile, locale);
}

export default async function UserProfilePage({ params }: Props) {
  const { id } = await params;
  const userId = parseUserId(id);

  if (userId === null) {
    notFound();
  }

  const profile = await fetchSellerProfileServer(String(userId));

  if (!profile) {
    notFound();
  }

  return <SellerProfileClient userId={profile.id} initialProfile={profile} />;
}
