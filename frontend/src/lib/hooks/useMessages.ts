'use client';

import { useState, useEffect, useRef } from 'react';
import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/firestore';
import { useAuthStore } from '@/store/auth.store';
import { writeChatMessage } from '@/lib/firebase/chatWrites';

// ── Types ──────────────────────────────────────────────────────────────────────

export interface ChatMessage {
  id: string;
  senderUid: string;
  senderId: string;
  text: string;
  type: 'text' | 'image';
  imageUrl?: string;
  isRead: boolean;
  readAt: { _seconds: number } | null;
  createdAt: { _seconds: number; _nanoseconds: number };
}

interface UseMessagesResult {
  messages: ChatMessage[];
  loading: boolean;
  error: string | null;
  sendMessage: (text: string) => Promise<void>;
  sendImage:   (imageUrl: string) => Promise<void>;
}

const MESSAGES_LIMIT = 100;

/**
 * Real-time hook for a single conversation's messages.
 * Listens to Firestore subcollection conversations/{id}/messages, ordered by createdAt.
 * Auto-marks messages as read when the conversation is opened.
 */
export function useMessages(conversationId: string | null): UseMessagesResult {
  const { user } = useAuthStore();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);
  const unsubRef = useRef<Unsubscribe | null>(null);

  useEffect(() => {
    if (!conversationId || !user?.id) {
      setMessages([]);
      setLoading(false);
      return;
    }

    const q = query(
      collection(db, 'conversations', conversationId, 'messages'),
      orderBy('createdAt', 'asc'),
      limit(MESSAGES_LIMIT)
    );

    unsubRef.current = onSnapshot(
      q,
      (snapshot) => {
        const msgs = snapshot.docs.map(d => ({
          id: d.id,
          ...d.data(),
        })) as ChatMessage[];
        setMessages(msgs);
        setLoading(false);
        setError(null);

        // Mark unread received messages as read
        const myId = String(user.id);
        snapshot.docs.forEach(d => {
          const data = d.data();
          if (data.senderId !== myId && !data.isRead) {
            updateDoc(d.ref, { isRead: true, readAt: serverTimestamp() }).catch(() => {});
          }
        });

        // Reset my unread count on the conversation doc
        const convRef = doc(db, 'conversations', conversationId);
        updateDoc(convRef, { [`unreadCount.${myId}`]: 0 }).catch(() => {});
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );

    return () => { unsubRef.current?.(); };
  }, [conversationId, user?.id]);

  const sendMessage = async (text: string): Promise<void> => {
    if (!conversationId || !user?.id || !text.trim()) return;
    await writeChatMessage({
      conversationId,
      myId: String(user.id),
      type: 'text',
      text,
    });
  };

  const sendImage = async (imageUrl: string): Promise<void> => {
    if (!conversationId || !user?.id) return;
    await writeChatMessage({
      conversationId,
      myId: String(user.id),
      type: 'image',
      imageUrl,
    });
  };

  return { messages, loading, error, sendMessage, sendImage };
}
