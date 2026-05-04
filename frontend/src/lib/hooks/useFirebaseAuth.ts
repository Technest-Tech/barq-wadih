'use client';

import { useState, useEffect, useRef } from 'react';
import { signInWithCustomToken, signOut, type User as FirebaseUser } from 'firebase/auth';
import { firebaseAuth } from '@/lib/firebase/auth';
import { getFirebaseToken } from '@/lib/api/chat';
import { authApi } from '@/lib/api/auth';
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
  const { isAuthenticated, user, updateUser } = useAuthStore();
  const [state, setState] = useState<FirebaseAuthState>({
    firebaseUser: null,
    isReady: false,
    error: null,
  });
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Refetch /me whenever the cached auth blob's `firebase_uid` is missing or
  // stale. After the backend stabilization, /me always returns strval(id);
  // any cached value that disagrees is from a pre-fix session and would
  // cause the stale-UID check below to keep using the wrong cached Firebase
  // session, leading to "Missing or insufficient permissions" on Firestore.
  useEffect(() => {
    if (!isAuthenticated || !user?.id) return;
    const expected = String(user.id);
    if (user.firebase_uid === expected) return;
    authApi.me()
      .then(res => {
        if (res.data) {
          console.log('[firebaseAuth] refreshed user from /me, firebase_uid =', res.data.firebase_uid);
          updateUser(res.data);
        }
      })
      .catch(err => console.warn('[firebaseAuth] /me refresh failed:', err));
  }, [isAuthenticated, user?.id, user?.firebase_uid, updateUser]);

  const signIn = async () => {
    try {
      const token = await getFirebaseToken();
      const cred  = await signInWithCustomToken(firebaseAuth, token);

      console.log('[firebaseAuth] signed in:', { uid: cred.user.uid, sanctumUserId: user?.id });
      setState({ firebaseUser: cred.user, isReady: true, error: null });

      // Schedule refresh 55 minutes from now (token valid for 60 min)
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
      refreshTimerRef.current = setTimeout(signIn, 55 * 60 * 1000);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Firebase auth failed';
      console.error('[firebaseAuth] sign-in failed:', msg);
      setState(prev => ({ ...prev, isReady: true, error: msg }));
    }
  };

  useEffect(() => {
    if (!isAuthenticated || !user?.id) {
      setState({ firebaseUser: null, isReady: true, error: null });
      return;
    }

    // If the cached `user.firebase_uid` doesn't match the backend's formula
    // (strval(id)), the auth blob is stale and the /me refresh effect above
    // is already in flight. Hold isReady at false so dependent listeners
    // (useConversations / useMessages) don't subscribe with a Firebase
    // session that's about to be torn down — that's what produced the
    // brief "Missing or insufficient permissions" error on initial render.
    const expected = String(user.id);
    if (user.firebase_uid !== expected) {
      setState({ firebaseUser: null, isReady: false, error: null });
      return;
    }

    const current      = firebaseAuth.currentUser;
    // The exact UID the backend will mint for this user. Comes from
    // UserResource ('firebase_uid' ?? strval(id)) and is the same value
    // baked into participantUids on every conversation doc this user is in.
    const expectedUid  = user.firebase_uid;

    console.log('[firebaseAuth] check:', {
      sanctumUserId: user.id,
      expectedUid,
      cachedUid: current?.uid ?? null,
    });

    // Stale if:
    //   - any "user_*" prefix (legacy bug from old contact-modal fallback)
    //   - cached UID does not match the backend's expected UID
    const looksStale = current && (
      current.uid.startsWith('user_') ||
      (expectedUid && current.uid !== expectedUid)
    );

    if (looksStale) {
      console.warn('[firebaseAuth] stale UID detected, re-signing in:', {
        cached: current.uid,
        expected: expectedUid,
      });
      // Set isReady: false BEFORE signing out so that any active Firestore
      // listeners (gated on isReady) are torn down by React before the auth
      // token is invalidated. Tearing down listeners mid-flight while auth
      // changes causes the Firestore SDK "Unexpected state (ID: ca9)" error.
      setState({ firebaseUser: null, isReady: false, error: null });
      signOut(firebaseAuth)
        .catch(() => {})
        .then(() => signIn());
      return;
    }

    if (current) {
      console.log('[firebaseAuth] reusing cached session:', current.uid);
      setState({ firebaseUser: current, isReady: true, error: null });
      return;
    }

    signIn();

    return () => {
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated, user?.id, user?.firebase_uid]);

  return state;
}
