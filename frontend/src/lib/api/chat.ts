import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ──────────────────────────────────────────────────────────────────────

export interface ConversationSummary {
  id: string;
  adId: string;
  adTitle: string;
  adImage: string | null;
  participantIds: string[];
  lastMessage: string | null;
  lastMessageAt: { _seconds: number; _nanoseconds: number } | null;
  lastMessageSenderId: string | null;
  unreadCount: Record<string, number>;
  my_unread_count: number;
  createdAt: { _seconds: number; _nanoseconds: number };
}

export interface CreateConversationResult {
  conversation_id: string;
  is_new: boolean;
  ad: { id: number; title: string; price: string | null; is_free: boolean };
  seller: { id: number; name: string; avatar: string | null };
}

// ── API functions ──────────────────────────────────────────────────────────────

/** Mint a Firebase custom token so this web user can access Firestore. */
export async function getFirebaseToken(): Promise<string> {
  const res = await apiClient.get<{ firebase_token: string }>(ENDPOINTS.CHAT_TOKEN);
  return res.data.firebase_token;
}

/** Create or find an existing conversation for an ad. Returns the conversation ID. */
export async function createConversation(adId: number): Promise<CreateConversationResult> {
  const res = await apiClient.post<CreateConversationResult>(
    ENDPOINTS.CHAT_CREATE,
    { ad_id: adId }
  );
  return res.data;
}

/** Tell the backend to push-notify the message receiver (Sprint 10 FCM stub). */
export async function notifyNewMessage(
  conversationId: string,
  receiverId: number,
  messagePreview: string
): Promise<void> {
  await apiClient.post(ENDPOINTS.CHAT_NOTIFY(conversationId), {
    receiver_id:     receiverId,
    message_preview: messagePreview,
  });
}
