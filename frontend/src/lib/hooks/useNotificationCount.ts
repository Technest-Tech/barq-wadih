'use client';

import { useQuery } from '@tanstack/react-query';
import { fetchUnreadCount } from '@/lib/api/notifications';
import { useAuthStore } from '@/store/auth.store';

/** Shared query key so pages can invalidate the count after marking notifications read. */
export const NOTIFICATION_COUNT_KEY = ['notifications', 'unread-count'] as const;

/**
 * Live unread-notification count for the header bell badge.
 *
 * The backend `Notification` table is the source of truth (a new chat message,
 * rating, follow, etc. each insert a row via PushService). There's no realtime
 * channel for it, so we poll `/notifications/unread-count` on an interval and
 * on window focus. Pages that mark notifications read should invalidate
 * [NOTIFICATION_COUNT_KEY] so the badge drops immediately instead of waiting
 * for the next poll.
 */
export function useNotificationCount(): number {
  const { isAuthenticated } = useAuthStore();

  const { data } = useQuery({
    queryKey: NOTIFICATION_COUNT_KEY,
    queryFn: fetchUnreadCount,
    enabled: isAuthenticated,
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
    staleTime: 10_000,
  });

  return data ?? 0;
}
