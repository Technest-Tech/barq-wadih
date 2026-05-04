'use client';

import { useEffect, useState, useCallback } from 'react';
import {
  toggleSellerFollow,
  fetchSellerFollowStatus,
  fetchFollowedSellers,
  type FollowedSellerEntry,
} from './api/sellerFollows';
import { useAuthStore } from '@/store/auth.store';

// ── Cross-component sync ─────────────────────────────────────────────────────

const EVENT_NAME = 'bw:seller_follows_changed';

interface FollowChangePayload {
  sellerId: number;
  following: boolean;
}

function emitChange(payload: FollowChangePayload) {
  if (typeof window === 'undefined') return;
  window.dispatchEvent(new CustomEvent<FollowChangePayload>(EVENT_NAME, { detail: payload }));
}

function subscribeChange(handler: (p: FollowChangePayload) => void) {
  const onEvt = (e: Event) => handler((e as CustomEvent<FollowChangePayload>).detail);
  window.addEventListener(EVENT_NAME, onEvt);
  return () => window.removeEventListener(EVENT_NAME, onEvt);
}

// ── Hook: list of followed sellers ──────────────────────────────────────────

export function useFollowedSellers() {
  const { isAuthenticated } = useAuthStore();
  const [list, setList]       = useState<FollowedSellerEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!isAuthenticated) {
      setList([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await fetchFollowedSellers();
      setList(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'failed to load follows');
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => { reload(); }, [reload]);

  useEffect(() => {
    return subscribeChange(({ sellerId, following }) => {
      if (!following) {
        setList(prev => prev.filter(e => e.seller.id !== sellerId));
      } else {
        // Refetch to pick up the new entry with full seller info.
        reload();
      }
    });
  }, [reload]);

  return { list, loading, error, reload };
}

// ── Hook: is following a single seller? ──────────────────────────────────────

export function useIsFollowingSeller(sellerId: number | null | undefined) {
  const { isAuthenticated } = useAuthStore();
  const [following, setFollowing] = useState(false);
  const [busy, setBusy]           = useState(false);

  // Initial / on-id-change fetch
  useEffect(() => {
    let cancelled = false;
    if (!isAuthenticated || sellerId == null) {
      setFollowing(false);
      return;
    }
    fetchSellerFollowStatus(sellerId)
      .then(res => { if (!cancelled) setFollowing(res.is_following); })
      .catch(() => { if (!cancelled) setFollowing(false); });
    return () => { cancelled = true; };
  }, [isAuthenticated, sellerId]);

  // React to changes from elsewhere
  useEffect(() => {
    if (sellerId == null) return;
    return subscribeChange(({ sellerId: changedId, following: nextState }) => {
      if (changedId === sellerId) setFollowing(nextState);
    });
  }, [sellerId]);

  const toggle = useCallback(async () => {
    if (sellerId == null || busy) return following;
    setBusy(true);
    // Optimistic update
    const next = !following;
    setFollowing(next);
    try {
      const res = await toggleSellerFollow(sellerId);
      setFollowing(res.is_following);
      emitChange({ sellerId, following: res.is_following });
      return res.is_following;
    } catch (e) {
      // Roll back optimistic update on error.
      setFollowing(following);
      throw e;
    } finally {
      setBusy(false);
    }
  }, [sellerId, busy, following]);

  return { following, busy, toggle };
}
