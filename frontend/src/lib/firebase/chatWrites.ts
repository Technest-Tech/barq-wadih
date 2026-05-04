import {
  addDoc,
  collection,
  doc,
  increment,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/firestore';
import { firebaseAuth } from '@/lib/firebase/auth';
import { signInWithCustomToken } from 'firebase/auth';
import { getFirebaseToken } from '@/lib/api/chat';

/**
 * Metadata returned by `POST /chat/conversations`. Used by the client to
 * `setDoc(merge:true)` the conversation document on the first message — the
 * backend never touches Firestore itself, so this seeds the doc the first
 * time a participant writes to it.
 */
export interface ConversationSeed {
  conversationId: string;
  participantIds:  [string, string];
  participantUids: [string, string];
  adId:    string;
  adTitle: string;
  adImage: string | null;
  /** Map of participant id -> display name. Used to render the peer's name
   *  in the conversation list and chat header without an extra lookup. */
  participantNames: Record<string, string>;
  /** Map of participant id -> avatar URL. Used to render the peer's profile
   *  photo (instead of the ad image) in the conversation list and header. */
  participantAvatars?: Record<string, string | null>;
}

interface BaseWrite {
  conversationId: string;
  myId: string;
  /** Optional metadata used to seed the parent doc the first time. */
  seed?: ConversationSeed;
}

interface TextPayload extends BaseWrite {
  type: 'text';
  text: string;
}

interface ImagePayload extends BaseWrite {
  type: 'image';
  imageUrl: string;
}

type WritePayload = TextPayload | ImagePayload;

/**
 * Ensures the current Sanctum-authenticated user is also signed into Firebase Auth.
 * Uses the cached Firebase user when present; otherwise mints a custom token via
 * the Laravel backend. Safe to call repeatedly.
 */
export async function ensureFirebaseSignedIn(): Promise<string> {
  const current = firebaseAuth.currentUser;
  if (current) return current.uid;

  const token = await getFirebaseToken();
  const cred  = await signInWithCustomToken(firebaseAuth, token);
  return cred.user.uid;
}

/**
 * Writes one message to conversations/{id}/messages and idempotently seeds /
 * updates the parent conversation doc. Uses setDoc(merge:true) so that:
 *
 *   - If the doc doesn't exist, it's CREATED with all required fields, which
 *     satisfies the `create` rule (read on a non-existent doc is forbidden,
 *     so we never call getDoc here).
 *   - If the doc exists, it's MERGE-UPDATED, which satisfies the `update` rule.
 *
 * Unread count is incremented (not overwritten) via FieldValue.increment(1).
 */
export async function writeChatMessage(payload: WritePayload): Promise<void> {
  const { conversationId, myId, seed } = payload;

  // Sign in (or reuse) the cached Firebase session. Stale UIDs are now
  // detected and cleaned up at boot inside useFirebaseAuth — doing it here
  // mid-write tears down active Firestore listeners and can trigger the
  // "Unexpected state" SDK assertion.
  const myUid = await ensureFirebaseSignedIn();

  if (seed && !seed.participantUids.includes(myUid)) {
    throw new Error(
      'تعذّر مطابقة هويتك مع المحادثة. يُرجى تسجيل الخروج ثم الدخول مرة أخرى.'
    );
  }

  // Identify the recipient for the unread counter.
  // Without a seed (subsequent message from useMessages) we still need to know
  // it — pull it from the seed when we have one; otherwise assume it's NOT us
  // and let the bump apply to the lone known peer key once we read the doc.
  const otherId = seed?.participantIds.find(id => id !== myId)
    ?? null;

  if (!seed && !otherId) {
    // We don't have the seed and we don't know the peer — fall back to a
    // best-effort metadata-only update via the doc's existing data. The
    // calling hook (useMessages) only triggers this AFTER the conversation
    // exists, so this branch is rare. Use a minimal update:
    await setDoc(
      doc(db, 'conversations', conversationId),
      {
        lastMessage: payload.type === 'text' ? payload.text.trim() : '📷 صورة',
        lastMessageAt:       serverTimestamp(),
        lastMessageSenderId: myId,
        updatedAt:           serverTimestamp(),
      },
      { merge: true }
    );
    await addDoc(collection(db, 'conversations', conversationId, 'messages'), {
      senderUid: myUid,
      senderId:  myId,
      isRead:    false,
      readAt:    null,
      createdAt: serverTimestamp(),
      type:      payload.type,
      text:      payload.type === 'text' ? payload.text.trim() : '📷 صورة',
      imageUrl:  payload.type === 'image' ? payload.imageUrl : null,
    });
    return;
  }

  const lastMessage = payload.type === 'text' ? payload.text.trim() : '📷 صورة';
  const now = serverTimestamp();

  const convRef = doc(db, 'conversations', conversationId);

  if (seed) {
    // First-message path: write a fully-populated doc. The Firestore `create`
    // rule requires all the keys below to be present at the TOP level, so we
    // use a literal `unreadCount` object (not dotted-path) to be unambiguous.
    // setDoc(merge:true) keeps it idempotent — repeat clicks won't error.
    await setDoc(
      convRef,
      {
        participantIds:     seed.participantIds,
        participantUids:    seed.participantUids,
        participantNames:   seed.participantNames,
        participantAvatars: seed.participantAvatars ?? {},
        adId:               seed.adId,
        adTitle:            seed.adTitle,
        adImage:            seed.adImage,
        lastMessage,
        lastMessageAt:       now,
        lastMessageSenderId: myId,
        unreadCount: {
          [myId]:               0,
          [otherId as string]:  1,
        },
        createdAt: now,
        updatedAt: now,
      },
      { merge: true }
    );
  } else {
    // Subsequent-message path: doc exists, rule fires `update` → just isParticipant().
    await setDoc(
      convRef,
      {
        lastMessage,
        lastMessageAt:       now,
        lastMessageSenderId: myId,
        [`unreadCount.${otherId}`]: increment(1),
        updatedAt:           now,
      },
      { merge: true }
    );
  }

  // Append the actual message.
  await addDoc(collection(db, 'conversations', conversationId, 'messages'), {
    senderUid: myUid,
    senderId:  myId,
    isRead:    false,
    readAt:    null,
    createdAt: now,
    type:      payload.type,
    text:      payload.type === 'text' ? payload.text.trim() : '📷 صورة',
    imageUrl:  payload.type === 'image' ? payload.imageUrl : null,
  });
}
