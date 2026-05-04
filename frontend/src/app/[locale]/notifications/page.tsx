'use client';

import React, { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  fetchNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  type INotification,
} from '@/lib/api/notifications';
import Header from '@/components/layout/Header/Header';
import Footer from '@/components/layout/Footer/Footer';
import styles from './page.module.css';

function relativeTime(dateStr: string): string {
  const diffMs  = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1)  return 'الآن';
  if (diffMin < 60) return `منذ ${diffMin} دقيقة`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `منذ ${diffHr} ساعة`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 30) return `منذ ${diffDay} يوم`;
  return new Date(dateStr).toLocaleDateString('ar-SA');
}

function notifIcon(type: string): string {
  switch (type) {
    case 'new_ad_followed': return '📢';
    case 'new_message':     return '💬';
    case 'new_rating':      return '⭐';
    default:                return '🔔';
  }
}

function notifHref(n: INotification, locale: string): string {
  const data = n.data ?? {};
  if (data.type === 'new_ad' && data.ad_id) return `/${locale}/ads/${data.ad_id}`;
  if (data.type === 'chat' && data.conversation_id) return `/${locale}/messages/${data.conversation_id}`;
  if (data.type === 'rating' && data.ad_id) return `/${locale}/ads/${data.ad_id}`;
  return `/${locale}/notifications`;
}

export default function NotificationsPage() {
  const { locale } = useParams<{ locale: string }>();
  const [items, setItems]     = useState<INotification[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage]       = useState(1);
  const [hasMore, setHasMore] = useState(false);

  const load = useCallback(async (p: number) => {
    const res = await fetchNotifications(p);
    setItems((prev) => p === 1 ? res.data : [...prev, ...res.data]);
    setHasMore(res.meta.current_page < res.meta.last_page);
    setPage(p);
  }, []);

  useEffect(() => {
    setLoading(true);
    load(1).finally(() => setLoading(false));
  }, [load]);

  async function handleMarkAll() {
    await markAllNotificationsRead();
    setItems((prev) => prev.map((n) => ({ ...n, is_read: true })));
  }

  async function handleClick(n: INotification) {
    if (!n.is_read) {
      await markNotificationRead(n.id);
      setItems((prev) => prev.map((i) => i.id === n.id ? { ...i, is_read: true } : i));
    }
  }

  const unreadCount = items.filter((n) => !n.is_read).length;

  return (
    <>
      <Header />

      <main className={styles.page}>
        <div className={styles.container}>
          <div className={styles.header}>
            <h1 className={styles.title}>🔔 الإشعارات</h1>
            {unreadCount > 0 && (
              <button className={styles.markAllBtn} onClick={handleMarkAll}>
                تعيين الكل كمقروء ({unreadCount})
              </button>
            )}
          </div>

          {loading ? (
            <div className={styles.skeletonList}>
              {Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className={styles.skeleton} />
              ))}
            </div>
          ) : items.length === 0 ? (
            <div className={styles.empty}>
              <div className={styles.emptyIcon}>🔕</div>
              <h2>لا توجد إشعارات</h2>
              <p>ستظهر هنا إشعاراتك عند وصولها</p>
            </div>
          ) : (
            <>
              <div className={styles.list}>
                {items.map((n) => (
                  <Link
                    key={n.id}
                    href={notifHref(n, locale)}
                    className={`${styles.item} ${!n.is_read ? styles.unread : ''}`}
                    onClick={() => handleClick(n)}
                  >
                    <span className={styles.icon}>{notifIcon(n.type)}</span>
                    <div className={styles.content}>
                      <span className={styles.itemTitle}>{n.title}</span>
                      {n.body && <span className={styles.body}>{n.body}</span>}
                      <span className={styles.time}>{relativeTime(n.created_at)}</span>
                    </div>
                    {!n.is_read && <span className={styles.dot} />}
                  </Link>
                ))}
              </div>
              {hasMore && (
                <button className={styles.loadMore} onClick={() => load(page + 1)}>
                  تحميل المزيد
                </button>
              )}
            </>
          )}
        </div>
      </main>

      <Footer />
    </>
  );
}
