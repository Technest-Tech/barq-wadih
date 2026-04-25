import createMiddleware from 'next-intl/middleware';
import { routing } from './i18n/routing';

export default createMiddleware(routing);

export const config = {
  matcher: [
    // Match all paths except Next.js internals, static assets, and API routes
    '/((?!_next|_vercel|api|.*\\..*).*)',
  ],
};
