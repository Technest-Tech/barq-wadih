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
 * Pass `enabled = false` (e.g. while Firebase Auth is still signing in) to
 * prevent the listener from starting before auth is ready. Starting a Firestore
 * listener before auth is stable can cause the SDK to throw
 * "Unexpected state" assertion errors when the auth token changes mid-flight.
 */
export function useConversations(enabled = true): UseConversationsResult {
  const { user } = useAuthStore();
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [loading, setLoading]             = useState(true);
  const [error, setError]                 = useState<string | null>(null);
  const unsubRef = useRef<Unsubscribe | null>(null);

  useEffect(() => {
    if (!enabled || !user?.firebase_uid || !user?.id) {
      setConversations([]);
      setLoading(!enabled);
      return;
    }

    const myUid = user.firebase_uid;
    const myId  = String(user.id);

    const q = query(
      collection(db, 'conversations'),
      where('participantUids', 'array-contains', myUid),
      orderBy('lastMessageAt', 'desc')
    );

    console.log('[useConversations] starting listener for uid =', myUid);

    unsubRef.current = onSnapshot(
      q,
      (snapshot) => {
        const docs = snapshot.docs.map(doc => ({
          ...doc.data(),
          id: doc.id,
          my_unread_count: (doc.data().unreadCount?.[myId] ?? 0) as number,
        })) as ConversationSummary[];
        console.log('[useConversations] snapshot received:', {
          myUid,
          docCount: docs.length,
          ids: docs.map(d => d.id),
        });
        setConversations(docs);
        setLoading(false);
        setError(null);
      },
      (err) => {
        console.error('[useConversations] listener error:', err);
        setError(err.message);
        setLoading(false);
      }
    );

    return () => {
      unsubRef.current?.();
    };
  }, [user?.id, user?.firebase_uid, enabled]);

  const totalUnread = conversations.reduce(
    (sum, c) => sum + (c.my_unread_count ?? 0),
    0
  );

  return { conversations, totalUnread, loading, error };
}
