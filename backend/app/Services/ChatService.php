<?php

namespace App\Services;

use App\Models\Ad;
use App\Models\User;
use App\Services\PushService;
use Kreait\Firebase\Contract\Firestore;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Google\Cloud\Firestore\FirestoreClient;

class ChatService
{
    private FirestoreClient $db;
    private FirebaseAuth $auth;

    public function __construct()
    {
        /** @var Firestore $firestore */
        $firestore = app('firebase.firestore');
        $this->db  = $firestore->database();

        /** @var FirebaseAuth $fbAuth */
        $fbAuth     = app('firebase.auth');
        $this->auth = $fbAuth;
    }

    // ── Mint a Firebase custom token for a Sanctum-authenticated user ─────────

    public function mintCustomToken(User $user): string
    {
        // Use the MySQL user ID as the Firebase UID so it's stable across devices.
        // If the user already has a firebase_uid (from phone OTP), use that instead.
        $uid = $user->firebase_uid ?? strval($user->id);

        return (string) $this->auth->createCustomToken($uid);
    }

    // ── Create or retrieve an existing conversation ───────────────────────────

    /**
     * Returns ['conversation_id' => string, 'is_new' => bool]
     */
    public function findOrCreateConversation(User $buyer, Ad $ad): array
    {
        $seller   = $ad->user;
        $buyerId  = strval($buyer->id);
        $sellerId = strval($seller->id);

        // Canonical participant order: always [smaller_id, larger_id] for stable dedup
        $participantIds = [(int)$buyerId < (int)$sellerId ? $buyerId : $sellerId,
                           (int)$buyerId < (int)$sellerId ? $sellerId : $buyerId];

        $adIdStr = strval($ad->id);

        // Query Firestore for an existing conversation between these two users on this ad
        $existing = $this->db
            ->collection('conversations')
            ->where('adId', '=', $adIdStr)
            ->where('participantIds', 'array-contains', $buyerId)
            ->documents();

        foreach ($existing as $doc) {
            if ($doc->exists()) {
                $data = $doc->data();
                // Confirm other participant is the seller
                if (in_array($sellerId, $data['participantIds'] ?? [])) {
                    return ['conversation_id' => $doc->id(), 'is_new' => false];
                }
            }
        }

        // Build Firebase UIDs (fall back to "user_{id}" sentinel if no Firebase account yet)
        $buyerUid  = $buyer->firebase_uid  ?? "user_{$buyer->id}";
        $sellerUid = $seller->firebase_uid ?? "user_{$seller->id}";

        $participantUids = [(int)$buyerId < (int)$sellerId ? $buyerUid : $sellerUid,
                            (int)$buyerId < (int)$sellerId ? $sellerUid : $buyerUid];

        // Primary image
        $adImage = $ad->images()->orderBy('sort_order')->value('image_url');

        $now = new \Google\Cloud\Core\Timestamp(new \DateTime());

        $docRef = $this->db->collection('conversations')->newDocument();
        $docRef->set([
            'participantIds'       => $participantIds,
            'participantUids'      => $participantUids,
            'adId'                 => $adIdStr,
            'adTitle'              => $ad->title,
            'adImage'              => $adImage,
            'lastMessage'          => null,
            'lastMessageAt'        => $now,
            'lastMessageSenderId'  => null,
            'unreadCount'          => [$buyerId => 0, $sellerId => 0],
            'createdAt'            => $now,
            'updatedAt'            => $now,
        ]);

        // Bump the ad's chat counter
        $ad->increment('chats_count');

        return ['conversation_id' => $docRef->id(), 'is_new' => true];
    }

    // ── List all conversations for a user (sorted by latest message) ──────────

    /**
     * Returns array of conversation data arrays, sorted by lastMessageAt desc.
     */
    public function listConversations(User $user): array
    {
        $userId = strval($user->id);

        $snapshot = $this->db
            ->collection('conversations')
            ->where('participantIds', 'array-contains', $userId)
            ->orderBy('lastMessageAt', 'DESCENDING')
            ->limit(50)
            ->documents();

        $conversations = [];
        foreach ($snapshot as $doc) {
            if (!$doc->exists()) {
                continue;
            }
            $data                     = $doc->data();
            $data['id']               = $doc->id();
            $data['my_unread_count']  = $data['unreadCount'][$userId] ?? 0;
            $conversations[]          = $data;
        }

        return $conversations;
    }

    // ── Trigger a push notification for a new message ─────────────────────────

    /**
     * Sends a real FCM push notification for a new chat message.
     */
    public function notifyNewMessage(
        string $conversationId,
        int $receiverId,
        string $messagePreview,
        User $sender
    ): void {
        app(PushService::class)->sendToUser(
            $receiverId,
            'new_message',
            "رسالة جديدة من {$sender->name}",
            mb_substr($messagePreview, 0, 80),
            [
                'type'            => 'chat',
                'conversation_id' => $conversationId,
                'sender_id'       => $sender->id,
                'sender_name'     => $sender->name,
            ],
        );
    }
}
