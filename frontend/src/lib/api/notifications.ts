import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { PaginatedResponse } from './types';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface INotification {
  id: number;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}

// ── API functions ─────────────────────────────────────────────────────────────

export async function fetchNotifications(
  page = 1,
): Promise<PaginatedResponse<INotification>> {
  return apiClient.getPaginated<INotification>(
    `${ENDPOINTS.NOTIFICATIONS}?page=${page}`,
  );
}

export async function markNotificationRead(id: number): Promise<void> {
  await apiClient.post(ENDPOINTS.NOTIFICATION_READ(id), {});
}

export async function markAllNotificationsRead(): Promise<void> {
  await apiClient.post(ENDPOINTS.NOTIFICATIONS_READ_ALL, {});
}

export async function fetchUnreadCount(): Promise<number> {
  const res = await apiClient.get<{ count: number }>(
    ENDPOINTS.NOTIFICATIONS_UNREAD,
  );
  return res.data?.count ?? 0;
}
