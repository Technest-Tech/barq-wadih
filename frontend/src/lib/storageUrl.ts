/**
 * Resolves a possibly-relative storage path to an absolute URL.
 *
 * Some older Firestore conversation docs have avatars stored as relative
 * paths (e.g. "avatars/10/abc.jpg") that the backend was supposed to expand
 * to a full URL via the `avatar_url` accessor. When those leak into the
 * client, the browser interprets them as relative to the current page —
 * `http://localhost:3000/messages/avatars/10/abc.jpg` → 404.
 *
 * This helper catches that case and prepends the Laravel storage URL.
 */
export function resolveStorageUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith('/')) return value;

  // NEXT_PUBLIC_API_URL = "http://localhost:8080/api" → strip the trailing
  // "/api" and append "/storage/<path>" (matches Laravel's public disk URL).
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? '';
  const origin = apiUrl.replace(/\/api\/?$/, '');
  return `${origin}/storage/${value.replace(/^\/+/, '')}`;
}
