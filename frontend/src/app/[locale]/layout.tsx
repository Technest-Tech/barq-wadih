import type { Metadata, Viewport } from 'next';
import { NextIntlClientProvider } from 'next-intl';
import { getMessages } from 'next-intl/server';
import { notFound } from 'next/navigation';
import { routing } from '@/i18n/routing';
import QueryProvider from '@/components/providers/QueryProvider';
import ThemeProvider from '@/components/providers/ThemeProvider';
import { AuthProvider } from '@/components/providers/AuthProvider';

type Props = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

export async function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export const viewport: Viewport = {
  themeColor: '#ffffff',
  width: 'device-width',
  initialScale: 1,
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const isArabic   = locale === 'ar';

  return {
    title: {
      default:  isArabic ? 'برق واضح' : 'Barq Wadih',
      template: isArabic ? '%s | برق واضح' : '%s | Barq Wadih',
    },
    description: isArabic
      ? 'منصة الإعلانات المبوبة الأولى في المملكة العربية السعودية — بيع وشراء بثقة وأمان'
      : "Saudi Arabia's Premier Classifieds Marketplace — Buy and sell with confidence",
    metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'),
    openGraph: {
      type: 'website',
      siteName: isArabic ? 'برق واضح' : 'Barq Wadih',
      locale: isArabic ? 'ar_SA' : 'en_US',
    },
    twitter: {
      card: 'summary',
    },
    robots: {
      index: true,
      follow: true,
    },
  };
}

export default async function LocaleLayout({ children, params }: Props) {
  const { locale } = await params;

  if (!routing.locales.includes(locale as 'ar' | 'en')) {
    notFound();
  }

  const messages = await getMessages();

  // <html>/<body> live in the root layout (src/app/layout.tsx).
  // This layout only wraps children with the required providers.
  return (
    <NextIntlClientProvider messages={messages}>
      <ThemeProvider>
        <QueryProvider>
          <AuthProvider>
            {children}
          </AuthProvider>
        </QueryProvider>
      </ThemeProvider>
    </NextIntlClientProvider>
  );
}
