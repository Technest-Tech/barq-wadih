'use client';

import React, { useEffect, useState, useRef, useCallback } from 'react';
import Link from 'next/link';
import {
  fetchNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  fetchUnreadCount,
  type INotification,
} from '@/lib/api/notifications';
import { useConversations } from '@/lib/hooks/useConversations';
import { useFirebaseAuth } from '@/lib/hooks/useFirebaseAuth';
import styles from './NotificationDropdown.module.css';

function relativeTime(dateStr: string): string {
  const diffMs  = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1)  return 'الآن';
  if (diffMin < 60) return `منذ ${diffMin} د`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `منذ ${diffHr} س`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 7) return `منذ ${diffDay} ي`;
  return new Date(dateStr).toLocaleDateString('ar-SA');
}

function notifIcon(type: string): string {
  switch (type) {
    case 'new_ad_followed':      return '📢';
    case 'new_message':          return '💬';
    case 'new_rating':           return '⭐';
    case 'commission_approved':  return '✅';
    case 'commission_rejected':  return '⚠️';
    default:                     return '🔔';
  }
}

function notifHref(n: INotification, locale: string): string {
  const data = n.data ?? {};
  if (data.type === 'new_ad' && data.ad_id) return `/${locale}/ads/${data.ad_id}`;
  if (data.type === 'chat' && data.conversation_id) return `/${locale}/messages/${data.conversation_id}`;
  if (data.type === 'rating' && data.ad_id) return `/${locale}/ads/${data.ad_id}`;
  if (data.type === 'commission_approved' && data.ad_id) return `/${locale}/ads/${data.ad_id}`;
  if (data.type === 'commission_rejected' && data.ad_id) return `/${locale}/post-ad/pay/${data.ad_id}`;
  return `/${locale}/notifications`;
}

interface NotificationDropdownProps {
  locale: string;
}

export default function NotificationDropdown({ locale }: NotificationDropdownProps) {
  const [open, setOpen]       = useState(false);
  const [items, setItems]     = useState<INotification[]>([]);
  const [unread, setUnread]   = useState(0);
  const [loaded, setLoaded]   = useState(false);
  const ref                   = useRef<HTMLDivElement>(null);

  // Real-time chat unread count from Firestore. Chat messages bypass the REST
  // notifications system (they're written client-side directly to Firestore),
  // so the bell would otherwise only update on the 30s poll — and never for
  // chat at all. Adding this gives instant badge updates when a peer sends a
  // message.
  const { isReady } = useFirebaseAuth();
  const { totalUnread: chatUnread } = useConversations(isReady);

  // Poll unread count every 30s
  const loadUnread = useCallback(async () => {
    try { setUnread(await fetchUnreadCount()); } catch { /* ignore */ }
  }, []);

  const totalBadge = unread + chatUnread;

  useEffect(() => {
    loadUnread();
    const timer = setInterval(loadUnread, 30_000);
    return () => clearInterval(timer);
  }, [loadUnread]);

  // Close on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  // Load latest 8 when dropdown opens
  useEffect(() => {
    if (open && !loaded) {
      fetchNotifications(1)
        .then((res) => { setItems(res.data.slice(0, 8)); setLoaded(true); })
        .catch(() => {});
    }
  }, [open, loaded]);

  async function handleMarkAll() {
    await markAllNotificationsRead();
    setUnread(0);
    setItems((prev) => prev.map((n) => ({ ...n, is_read: true })));
  }

  async function handleClick(n: INotification) {
    if (!n.is_read) {
      await markNotificationRead(n.id);
      setItems((prev) => prev.map((i) => i.id === n.id ? { ...i, is_read: true } : i));
      setUnread((c) => Math.max(0, c - 1));
    }
    setOpen(false);
  }

  return (
    <div className={styles.wrapper} ref={ref}>
      <button
        className={styles.bellBtn}
        onClick={() => setOpen(!open)}
        aria-label="الإشعارات"
      >
        🔔
        {totalBadge > 0 && (
          <span className={styles.badge}>{totalBadge > 99 ? '99+' : totalBadge}</span>
        )}
      </button>

      {open && (
        <div className={styles.dropdown}>
          <div className={styles.header}>
            <h3>الإشعارات</h3>
            {unread > 0 && (
              <button className={styles.markAll} onClick={handleMarkAll}>
                تعيين الكل كمقروء
              </button>
            )}
          </div>

          <div className={styles.list}>
            {items.length === 0 ? (
              <p className={styles.empty}>لا توجد إشعارات</p>
            ) : (
              items.map((n) => (
                <Link
                  key={n.id}
                  href={notifHref(n, locale)}
                  className={`${styles.item} ${!n.is_read ? styles.unread : ''}`}
                  onClick={() => handleClick(n)}
                >
                  <span className={styles.icon}>{notifIcon(n.type)}</span>
                  <div className={styles.content}>
                    <span className={styles.title}>{n.title}</span>
                    {n.body && <span className={styles.body}>{n.body}</span>}
                  </div>
                  <span className={styles.time}>{relativeTime(n.created_at)}</span>
                </Link>
              ))
            )}
          </div>

          <Link
            href={`/${locale}/notifications`}
            className={styles.viewAll}
            onClick={() => setOpen(false)}
          >
            عرض جميع الإشعارات
          </Link>
        </div>
      )}
    </div>
  );
}
