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
  addDoc,
  getDoc,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/firestore';
import { useAuthStore } from '@/store/auth.store';

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

  const getMyUid = async (): Promise<string> => {
    const { firebaseAuth } = await import('@/lib/firebase/auth');
    return firebaseAuth.currentUser?.uid ?? String(user?.id ?? '');
  };

  const sendMessage = async (text: string): Promise<void> => {
    if (!conversationId || !user?.id || !text.trim()) return;
    const myId  = String(user.id);
    const myUid = await getMyUid();

    const convRef = doc(db, 'conversations', conversationId);
    const convSnap = await getDoc(convRef);
    if (!convSnap.exists()) return;

    const otherParticipantId = (convSnap.data().participantIds as string[])
      .find(id => id !== myId) ?? '';

    const now = serverTimestamp();

    // Write message
    await addDoc(collection(db, 'conversations', conversationId, 'messages'), {
      senderUid:  myUid,
      senderId:   myId,
      text:       text.trim(),
      type:       'text',
      imageUrl:   null,
      isRead:     false,
      readAt:     null,
      createdAt:  now,
    });

    // Update conversation metadata
    await updateDoc(convRef, {
      lastMessage:         text.trim(),
      lastMessageAt:       now,
      lastMessageSenderId: myId,
      [`unreadCount.${otherParticipantId}`]:
        ((convSnap.data().unreadCount?.[otherParticipantId] ?? 0) as number) + 1,
      updatedAt: now,
    });
  };

  const sendImage = async (imageUrl: string): Promise<void> => {
    if (!conversationId || !user?.id) return;
    const myId  = String(user.id);
    const myUid = await getMyUid();

    const convRef  = doc(db, 'conversations', conversationId);
    const convSnap = await getDoc(convRef);
    if (!convSnap.exists()) return;

    const otherParticipantId = (convSnap.data().participantIds as string[])
      .find(id => id !== myId) ?? '';

    const now = serverTimestamp();

    await addDoc(collection(db, 'conversations', conversationId, 'messages'), {
      senderUid: myUid,
      senderId:  myId,
      text:      '📷 صورة',
      type:      'image',
      imageUrl,
      isRead:    false,
      readAt:    null,
      createdAt: now,
    });

    await updateDoc(convRef, {
      lastMessage:         '📷 صورة',
      lastMessageAt:       now,
      lastMessageSenderId: myId,
      [`unreadCount.${otherParticipantId}`]:
        ((convSnap.data().unreadCount?.[otherParticipantId] ?? 0) as number) + 1,
      updatedAt: now,
    });
  };

  return { messages, loading, error, sendMessage, sendImage };
}
