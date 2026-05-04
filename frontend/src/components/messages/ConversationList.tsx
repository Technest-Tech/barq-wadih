'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { MessageSquare, Search, Edit3 } from 'lucide-react';
import { useConversations } from '@/lib/hooks/useConversations';
import { useFirebaseAuth } from '@/lib/hooks/useFirebaseAuth';
import { useAuthStore } from '@/store/auth.store';
import { resolveStorageUrl } from '@/lib/storageUrl';
import styles from './ConversationList.module.css';

function relativeTime(seconds: number | null | undefined): string {
  if (!seconds) return '';
  const diffSec = Math.floor(Date.now() / 1000) - seconds;
  if (diffSec < 60)    return 'الآن';
  if (diffSec < 3600)  return `${Math.floor(diffSec / 60)} د`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} س`;
  return `${Math.floor(diffSec / 86400)} ي`;
}

interface Props {
  activeConversationId?: string | null;
}

export default function ConversationList({ activeConversationId }: Props) {
  const { locale } = useParams<{ locale: string }>();
  const { user } = useAuthStore();
  const { isReady } = useFirebaseAuth();
  // Only start the Firestore listener once Firebase Auth is confirmed ready.
  // Starting before auth is stable causes "Unexpected state" SDK crashes.
  const { conversations, totalUnread, loading } = useConversations(isReady);

  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'unread'>('all');

  const myId = String(user?.id ?? '');

  const peerNameOf = (c: typeof conversations[number]) => {
    const otherId = c.participantIds.find(id => id !== myId);
    if (otherId && c.participantNames?.[otherId]) {
      return c.participantNames[otherId];
    }
    return c.adTitle ?? 'محادثة';
  };

  const peerAvatarOf = (c: typeof conversations[number]): string | null => {
    const otherId = c.participantIds.find(id => id !== myId);
    if (otherId && c.participantAvatars?.[otherId]) {
      return resolveStorageUrl(c.participantAvatars[otherId]);
    }
    // Backwards-compat: older docs predate participantAvatars; fall back to
    // the ad image so the row isn't empty.
    return resolveStorageUrl(c.adImage);
  };

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return conversations.filter(c => {
      if (filter === 'unread' && (c.my_unread_count ?? 0) === 0) return false;
      if (!term) return true;
      const haystack = `${peerNameOf(c)} ${c.adTitle ?? ''} ${c.lastMessage ?? ''}`.toLowerCase();
      return haystack.includes(term);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversations, search, filter, myId]);

  return (
    <div className={styles.list}>
      <div className={styles.header}>
        <div className={styles.headerTop}>
          <h1 className={styles.title}>
            المحادثات
            {totalUnread > 0 && <span className={styles.totalBadge}>{totalUnread}</span>}
          </h1>
          <button className={styles.composeBtn} title="محادثة جديدة" type="button" disabled>
            <Edit3 size={16} />
          </button>
        </div>

        <div className={styles.searchBar}>
          <Search size={15} className={styles.searchIcon} />
          <input
            className={styles.searchInput}
            placeholder="البحث"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <div className={styles.chipsRow}>
          <button
            className={`${styles.chip} ${filter === 'all' ? styles.chipActive : ''}`}
            onClick={() => setFilter('all')}
            type="button"
          >
            الكل
          </button>
          <button
            className={`${styles.chip} ${filter === 'unread' ? styles.chipActive : ''}`}
            onClick={() => setFilter('unread')}
            type="button"
          >
            غير مقروء
            {totalUnread > 0 && <span className={styles.chipDot}>{totalUnread}</span>}
          </button>
        </div>
      </div>

      <div className={styles.scrollArea}>
        {loading || !isReady ? (
          [...Array(6)].map((_, i) => (
            <div key={i} className={styles.skeleton}>
              <div className={styles.skAvatar} />
              <div className={styles.skBody}>
                <div className={styles.skLine} style={{ width: '60%' }} />
                <div className={styles.skLine} style={{ width: '40%' }} />
              </div>
            </div>
          ))
        ) : filtered.length === 0 ? (
          <div className={styles.empty}>
            <MessageSquare size={42} strokeWidth={1.2} />
            <p>{search ? 'لا توجد نتائج' : 'لا توجد محادثات بعد'}</p>
            <span>ابدأ محادثة من صفحة أي إعلان</span>
          </div>
        ) : (
          filtered.map((conv) => {
            const myUnread = conv.my_unread_count ?? 0;
            const lastSec  = conv.lastMessageAt?._seconds ?? null;
            const isMe     = conv.lastMessageSenderId === myId;
            const href     = `/${locale}/messages/${conv.id}`;
            const isActive = conv.id === activeConversationId;
            const peerName   = peerNameOf(conv);
            const peerAvatar = peerAvatarOf(conv);
            const initial    = peerName.trim().charAt(0).toUpperCase() || '?';

            return (
              <Link
                key={conv.id}
                href={href}
                className={`${styles.row} ${isActive ? styles.rowActive : ''}`}
              >
                <div className={styles.avatar}>
                  {peerAvatar ? (
                    /* eslint-disable-next-line @next/next/no-img-element */
                    <img src={peerAvatar} alt="" className={styles.avatarImg} />
                  ) : (
                    <span className={styles.avatarInitial}>{initial}</span>
                  )}
                  {myUnread > 0 && <span className={styles.unreadDot} />}
                </div>

                <div className={styles.body}>
                  <div className={styles.bodyTop}>
                    <span className={styles.peer}>{peerName}</span>
                    <span className={`${styles.time} ${myUnread > 0 ? styles.timeUnread : ''}`}>
                      {relativeTime(lastSec)}
                    </span>
                  </div>
                  <div className={styles.bodyBottom}>
                    <span className={`${styles.preview} ${myUnread > 0 ? styles.previewUnread : ''}`}>
                      {isMe && <span className={styles.youLabel}>أنت: </span>}
                      {conv.lastMessage ?? `بخصوص: ${conv.adTitle ?? '...'}`}
                    </span>
                    {myUnread > 0 && (
                      <span className={styles.unreadBadge}>{myUnread}</span>
                    )}
                  </div>
                </div>
              </Link>
            );
          })
        )}
      </div>
    </div>
  );
}
