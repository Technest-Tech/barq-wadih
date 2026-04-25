import { defineRouting } from 'next-intl/routing';

export const routing = defineRouting({
  locales: ['ar', 'en'],
  defaultLocale: 'ar',
  localePrefix: 'as-needed',
  // Disable cookie/Accept-Language detection — always use defaultLocale (ar) at root
  localeDetection: false,
});
