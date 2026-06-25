'use client';

import { useEffect, useState, useCallback } from 'react';
import { fetchFollows, toggleCategoryFollow, type FollowedCategory } from './api/follows';
import { useAuthStore } from '@/store/auth.store';

// ── Hook: list of followed categories ───────────────────────────────────────

export function useFollowedCategories() {
  const { isAuthenticated } = useAuthStore();
  const [list, setList] = useState<FollowedCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    if (!isAuthenticated) {
      setList([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await fetchFollows();
      setList(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'failed to load follows');
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    reload();
  }, [reload]);

  // Remove a followed category (category + its city scope).
  const unfollow = useCallback(
    async (entry: FollowedCategory) => {
      // Optimistic removal — restore on failure.
      setList((prev) => prev.filter((e) => e.id !== entry.id));
      try {
        await toggleCategoryFollow(entry.category.id, entry.city?.id);
      } catch {
        reload();
      }
    },
    [reload]
  );

  return { list, loading, error, reload, unfollow };
}
