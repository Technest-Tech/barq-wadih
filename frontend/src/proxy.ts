import createMiddleware from 'next-intl/middleware';
import { NextResponse, type NextRequest } from 'next/server';
import { routing } from './i18n/routing';

const intlProxy = createMiddleware(routing);

/**
 * Public profile links are /@{handle}, but "@folder" is reserved by the App
 * Router for parallel-route slots, so the page lives at /u/[handle] and we
 * rewrite onto it here. The browser URL stays /@{handle}.
 *
 * Doing this as a rewrite — rather than a top-level [handle] segment — keeps
 * every other unmatched path on Next's built-in 404 instead of turning the
 * whole site into a soft 404 (a 200 that only says noindex in the body).
 *
 * The Arabic prefix is deliberately not matched: localePrefix is 'as-needed',
 * so next-intl already 307s /ar/@x to /@x, which then lands here.
 */
const HANDLE_PATH = /^\/(en\/)?@([A-Za-z0-9_]{1,30})$/;

export default function proxy(request: NextRequest) {
  const match = request.nextUrl.pathname.match(HANDLE_PATH);

  if (match) {
    const [, enPrefix, handle] = match;
    const locale = enPrefix ? 'en' : routing.defaultLocale;
    const url = request.nextUrl.clone();

    // Rewrite straight to the locale-prefixed route rather than delegating to
    // next-intl: it answers `next()` for paths that already carry a locale,
    // which would throw the rewritten path away.
    url.pathname = `/${locale}/u/${handle.toLowerCase()}`;

    // The root layout reads <html lang/dir> from the NEXT_LOCALE cookie, which
    // next-intl normally plants on both the request and the response. Do the
    // same, or an English profile would render inside an RTL Arabic shell.
    const headers = new Headers(request.headers);
    const cookies = request.cookies
      .getAll()
      .filter((cookie) => cookie.name !== 'NEXT_LOCALE')
      .map((cookie) => `${cookie.name}=${cookie.value}`);
    headers.set('cookie', [...cookies, `NEXT_LOCALE=${locale}`].join('; '));

    const response = NextResponse.rewrite(url, { request: { headers } });
    response.cookies.set('NEXT_LOCALE', locale, { path: '/', sameSite: 'lax' });

    return response;
  }

  return intlProxy(request);
}

export const config = {
  matcher: [
    // Match all paths except Next.js internals, static assets, and API routes
    '/((?!_next|_vercel|api|.*\\..*).*)',
  ],
};
