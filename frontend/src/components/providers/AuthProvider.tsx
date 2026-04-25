'use client';

import { useEffect } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { authApi } from '@/lib/api/auth';
import { useAuthStore } from '@/store/auth.store';

// Protected paths that require auth
const AUTH_REQUIRED_PREFIXES = ['/ar/dashboard', '/en/dashboard'];
// Auth pages that should redirect away if already logged in
const AUTH_PAGES = ['/ar/(auth)', '/en/(auth)', '/ar/login', '/en/login', '/ar/register', '/en/register'];

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const { token, setAuth, clearAuth, isAuthenticated } = useAuthStore();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (!token) return;

    // Validate token by fetching current user
    authApi.me()
      .then((res) => {
        if (res.data) setAuth(res.data, token);
      })
      .catch(() => {
        // Token invalid or expired
        clearAuth();
      });
  // Run once on mount
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return <>{children}</>;
}
