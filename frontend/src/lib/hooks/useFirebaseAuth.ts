'use client';

import { useState, useEffect, useRef } from 'react';
import { signInWithCustomToken, type User as FirebaseUser } from 'firebase/auth';
import { firebaseAuth } from '@/lib/firebase/auth';
import { getFirebaseToken } from '@/lib/api/chat';
import { useAuthStore } from '@/store/auth.store';

interface FirebaseAuthState {
  firebaseUser: FirebaseUser | null;
  isReady: boolean;
  error: string | null;
}

/**
 * Signs the currently logged-in Sanctum user into Firebase using a custom token
 * minted by the Laravel backend. Handles token refresh automatically (tokens
 * expire after 1 hour; we refresh 5 minutes before expiry).
 */
export function useFirebaseAuth(): FirebaseAuthState {
  const { isAuthenticated } = useAuthStore();
  const [state, setState] = useState<FirebaseAuthState>({
    firebaseUser: null,
    isReady: false,
    error: null,
  });
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const signIn = async () => {
    try {
      const token = await getFirebaseToken();
      const cred  = await signInWithCustomToken(firebaseAuth, token);

      setState({ firebaseUser: cred.user, isReady: true, error: null });

      // Schedule refresh 55 minutes from now (token valid for 60 min)
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
      refreshTimerRef.current = setTimeout(signIn, 55 * 60 * 1000);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Firebase auth failed';
      setState(prev => ({ ...prev, isReady: true, error: msg }));
    }
  };

  useEffect(() => {
    if (!isAuthenticated) {
      setState({ firebaseUser: null, isReady: true, error: null });
      return;
    }

    // Check if already signed in (hot reload / re-render)
    const current = firebaseAuth.currentUser;
    if (current) {
      setState({ firebaseUser: current, isReady: true, error: null });
      return;
    }

    signIn();

    return () => {
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated]);

  return state;
}
