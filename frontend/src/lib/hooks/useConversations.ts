'use client';

import { useState, useEffect, useRef } from 'react';
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/firestore';
import { useAuthStore } from '@/store/auth.store';
import { type ConversationSummary } from '@/lib/api/chat';

interface UseConversationsResult {
  conversations: ConversationSummary[];
  totalUnread: number;
  loading: boolean;
  error: string | null;
}

/**
 * Real-time hook that listens to Firestore for all conversations the current
 * user participates in, sorted by latest message.
 *
 * Uses participantIds (MySQL integer IDs as strings) for querying — this avoids
 * requiring a Firebase UID on every request and works immediately after
 * Sanctum login even before Firebase custom-token auth completes.
 */
export function useConversations(): UseConversationsResult {
  const { user } = useAuthStore();
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [loading, setLoading]             = useState(true);
  const [error, setError]                 = useState<string | null>(null);
  const unsubRef = useRef<Unsubscribe | null>(null);

  useEffect(() => {
    if (!user?.id) {
      setConversations([]);
      setLoading(false);
      return;
    }

    const userId = String(user.id);

    const q = query(
      collection(db, 'conversations'),
      where('participantIds', 'array-contains', userId),
      orderBy('lastMessageAt', 'desc')
    );

    unsubRef.current = onSnapshot(
      q,
      (snapshot) => {
        const docs = snapshot.docs.map(doc => ({
          ...doc.data(),
          id: doc.id,
          my_unread_count: (doc.data().unreadCount?.[userId] ?? 0) as number,
        })) as ConversationSummary[];
        setConversations(docs);
        setLoading(false);
        setError(null);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );

    return () => {
      unsubRef.current?.();
    };
  }, [user?.id]);

  const totalUnread = conversations.reduce(
    (sum, c) => sum + (c.my_unread_count ?? 0),
    0
  );

  return { conversations, totalUnread, loading, error };
}
