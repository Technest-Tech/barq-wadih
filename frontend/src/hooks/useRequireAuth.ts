import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/store/auth.store';

/**
 * Redirects to login if the store has finished hydrating and the user is not authenticated.
 * Returns { ready } — when false, the page should render nothing (avoids flash).
 */
export function useRequireAuth(loginPath = '/ar/login'): { ready: boolean } {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const hasHydrated     = useAuthStore((s) => s._hasHydrated);
  const router = useRouter();

  useEffect(() => {
    if (!hasHydrated) return;
    if (!isAuthenticated) router.replace(loginPath);
  }, [hasHydrated, isAuthenticated, loginPath, router]);

  return { ready: hasHydrated && isAuthenticated };
}
