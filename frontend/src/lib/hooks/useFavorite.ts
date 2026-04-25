'use client';

import { useState, useCallback } from 'react';
import { toggleFavorite } from '@/lib/api/favorites';

interface UseFavoriteOptions {
  initialState?: boolean;
  onToggle?: (isFavorited: boolean) => void;
}

export function useFavorite(adId: number, options: UseFavoriteOptions = {}) {
  const { initialState = false, onToggle } = options;
  const [isFavorited, setIsFavorited] = useState(initialState);
  const [isLoading, setIsLoading] = useState(false);

  const toggle = useCallback(async () => {
    if (isLoading) return;

    // Optimistic update
    const next = !isFavorited;
    setIsFavorited(next);
    setIsLoading(true);

    try {
      const res = await toggleFavorite(adId);
      setIsFavorited(res.is_favorited);
      onToggle?.(res.is_favorited);
    } catch {
      // Revert on error
      setIsFavorited(!next);
    } finally {
      setIsLoading(false);
    }
  }, [adId, isFavorited, isLoading, onToggle]);

  return { isFavorited, toggle, isLoading };
}
