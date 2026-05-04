import apiClient from './client';
import ENDPOINTS from './endpoints';

// ── Types ──────────────────────────────────────────────────────────────────────

export interface ConversationSummary {
  id: string;
  adId: string;
  adTitle: string;
  adImage: string | null;
  participantIds: string[];
  participantNames?: Record<string, string>;
  participantAvatars?: Record<string, string | null>;
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
  participant_ids:  [string, string];
  participant_uids: [string, string];
  ad: {
    id: number;
    title: string;
    price: string | null;
    is_free: boolean;
    image: string | null;
  };
  seller: {
    id: number;
    name: string;
    avatar: string | null;
    firebase_uid: string;
  };
  buyer: {
    id: number;
    name: string;
    avatar: string | null;
    firebase_uid: string;
  };
}

// ── API functions ──────────────────────────────────────────────────────────────

/** Mint a Firebase custom token so this web user can access Firestore. */
export async function getFirebaseToken(): Promise<string> {
  const res = await apiClient.get<{ firebase_token: string }>(ENDPOINTS.CHAT_TOKEN);
  return res.data.firebase_token;
}

/** Fetch the conversation seed metadata for an ad. The backend validates the
 *  ad and returns a deterministic conversation id + canonical participant
 *  ordering. The actual Firestore doc is created client-side on first write. */
export async function createConversation(adId: number): Promise<CreateConversationResult> {
  const res = await apiClient.post<CreateConversationResult>(
    ENDPOINTS.CHAT_CREATE,
    { ad_id: adId }
  );
  return res.data;
}

/**
 * Create or find a conversation and post the buyer's opening message in one shot.
 * Resolves to the backend metadata. Best-effort FCM notification afterwards.
 */
export async function startConversation(
  adId: number,
  initialMessage: string,
  myUserId: number,
): Promise<CreateConversationResult> {
  const { writeChatMessage } = await import('@/lib/firebase/chatWrites');

  const result = await createConversation(adId);

  await writeChatMessage({
    conversationId: result.conversation_id,
    myId: String(myUserId),
    type: 'text',
    text: initialMessage,
    seed: {
      conversationId:  result.conversation_id,
      participantIds:  result.participant_ids,
      participantUids: result.participant_uids,
      adId:    String(result.ad.id),
      adTitle: result.ad.title,
      adImage: result.ad.image,
      participantNames: {
        [String(result.buyer.id)]:  result.buyer.name,
        [String(result.seller.id)]: result.seller.name,
      },
      participantAvatars: {
        [String(result.buyer.id)]:  result.buyer.avatar,
        [String(result.seller.id)]: result.seller.avatar,
      },
    },
  });

  notifyNewMessage(result.conversation_id, result.seller.id, initialMessage)
    .catch(() => {});

  return result;
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
