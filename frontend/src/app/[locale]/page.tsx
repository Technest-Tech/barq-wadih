import type { Metadata } from 'next';
import { Suspense } from 'react';
import HomeClient from './HomeClient';

type Props = { params: Promise<{ locale: string }> };

// Server wrapper: adds a self-referencing canonical (+ hreflang) to the home
// page. The interactive UI lives in HomeClient (a client component that reads
// its own locale/search params via hooks). Without this canonical, Google
// flagged the locale + query-param home variants as "Duplicate without
// user-selected canonical".
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  return {
    alternates: {
      canonical: `/${locale}`,
      languages: { ar: '/ar', en: '/en' },
    },
  };
}

export default function HomePage() {
  return (
    <Suspense>
      <HomeClient />
    </Suspense>
  );
}
