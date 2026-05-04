import { cookies } from 'next/headers';
import '@/styles/globals.css';

// Root layout — owns the single <html>/<body> in the tree.
// Reads the NEXT_LOCALE cookie to set the correct lang/dir so the [locale]
// segment layout doesn't need to re-render these shell elements.
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const cookieStore = await cookies();
  const locale = cookieStore.get('NEXT_LOCALE')?.value ?? 'ar';
  const dir    = locale === 'ar' ? 'rtl' : 'ltr';

  return (
    <html lang={locale} dir={dir} suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" crossOrigin="anonymous" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
