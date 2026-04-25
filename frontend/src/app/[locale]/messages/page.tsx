'use client';

import { useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import Link from 'next/link';
import { MessageSquare, Search, ChevronLeft } from 'lucide-react';
import Header from '@/components/layout/Header/Header';
import { useConversations } from '@/lib/hooks/useConversations';
import { useFirebaseAuth } from '@/lib/hooks/useFirebaseAuth';
import { useAuthStore } from '@/store/auth.store';
import styles from './page.module.css';

// ── Helpers ───────────────────────────────────────────────────────────────────

function relativeTime(seconds: number | null | undefined): string {
  if (!seconds) return '';
  const diffSec = Math.floor(Date.now() / 1000) - seconds;
  if (diffSec < 60)   return 'الآن';
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)} د`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} س`;
  return `${Math.floor(diffSec / 86400)} ي`;
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function MessagesPage() {
  const { locale } = useParams<{ locale: string }>();
  const router     = useRouter();
  const { user, isAuthenticated } = useAuthStore();
  const { isReady }               = useFirebaseAuth();
  const { conversations, totalUnread, loading } = useConversations();
  const [search, setSearch] = useState('');

  // Not authenticated — redirect to login
  if (!isAuthenticated) {
    return (
      <>
        <Header />
        <main className={styles.emptyPage}>
          <div className={styles.emptyState}>
            <div className={styles.emptyIcon}><MessageSquare size={56} strokeWidth={1.2} /></div>
            <h2>سجّل الدخول للوصول إلى رسائلك</h2>
            <Link href={`/${locale}/login`} className={styles.loginBtn}>تسجيل الدخول</Link>
          </div>
        </main>
      </>
    );
  }

  const myId    = String(user?.id ?? '');
  const filtered = conversations.filter(c =>
    !search ||
    c.adTitle?.toLowerCase().includes(search.toLowerCase()) ||
    c.lastMessage?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <>
      <Header />
      <main className={styles.page} dir="rtl">
        <div className={styles.layout}>

          {/* ── Sidebar: Conversation list ── */}
          <aside className={styles.sidebar}>
            <div className={styles.sidebarHeader}>
              <h1 className={styles.sidebarTitle}>
                الرسائل
                {totalUnread > 0 && (
                  <span className={styles.totalBadge}>{totalUnread}</span>
                )}
              </h1>
              <div className={styles.searchBar}>
                <Search size={16} className={styles.searchIcon} />
                <input
                  className={styles.searchInput}
                  placeholder="بحث في الرسائل..."
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                />
              </div>
            </div>

            <div className={styles.convList}>
              {loading || !isReady ? (
                // Skeleton
                [...Array(5)].map((_, i) => (
                  <div key={i} className={styles.skConv}>
                    <div className={styles.skAvatar} />
                    <div className={styles.skText}>
                      <div className={styles.skLine} style={{ width: '60%' }} />
                      <div className={styles.skLine} style={{ width: '40%' }} />
                    </div>
                  </div>
                ))
              ) : filtered.length === 0 ? (
                <div className={styles.emptyConv}>
                  <MessageSquare size={40} strokeWidth={1} />
                  <p>لا توجد محادثات بعد</p>
                  <span>ابدأ محادثة من صفحة أي إعلان</span>
                </div>
              ) : (
                filtered.map(conv => {
                  const myUnread = conv.my_unread_count ?? 0;
                  const lastSec  = conv.lastMessageAt?._seconds ?? null;
                  const isMe     = conv.lastMessageSenderId === myId;
                  const href     = `/${locale}/messages/${conv.id}`;

                  return (
                    <Link key={conv.id} href={href} className={styles.convItem}>
                      {/* Ad thumbnail */}
                      <div className={styles.convThumb}>
                        {conv.adImage
                          // eslint-disable-next-line @next/next/no-img-element
                          ? <img src={conv.adImage} alt={conv.adTitle} className={styles.thumbImg} />
                          : <span className={styles.thumbFallback}>📦</span>
                        }
                      </div>

                      {/* Content */}
                      <div className={styles.convContent}>
                        <div className={styles.convTop}>
                          <span className={styles.adTitle}>{conv.adTitle}</span>
                          <span className={styles.convTime}>{relativeTime(lastSec)}</span>
                        </div>
                        <div className={styles.convBottom}>
                          <span className={`${styles.lastMsg} ${myUnread > 0 ? styles.unreadMsg : ''}`}>
                            {isMe && <span className={styles.youLabel}>أنت: </span>}
                            {conv.lastMessage ?? 'بدأت محادثة جديدة'}
                          </span>
                          {myUnread > 0 && (
                            <span className={styles.unreadBadge}>{myUnread}</span>
                          )}
                        </div>
                      </div>

                      <ChevronLeft size={16} className={styles.chevron} />
                    </Link>
                  );
                })
              )}
            </div>
          </aside>

          {/* ── Main panel: Empty state on desktop when no conv selected ── */}
          <div className={styles.mainPanel}>
            <div className={styles.noConvSelected}>
              <MessageSquare size={64} strokeWidth={1} className={styles.noConvIcon} />
              <h2>اختر محادثة للبدء</h2>
              <p>اختر من القائمة اليسرى أو ابدأ محادثة جديدة من صفحة أي إعلان</p>
            </div>
          </div>

        </div>
      </main>
    </>
  );
}
