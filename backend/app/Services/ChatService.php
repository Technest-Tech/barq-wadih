<?php

namespace App\Services;

use App\Models\Ad;
use App\Models\User;
use App\Services\PushService;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;

class ChatService
{
    private FirebaseAuth $auth;

    public function __construct()
    {
        /** @var FirebaseAuth $fbAuth */
        $fbAuth     = app('firebase.auth');
        $this->auth = $fbAuth;
    }

    // ── Mint a Firebase custom token for a Sanctum-authenticated user ─────────

    public function mintCustomToken(User $user): string
    {
        // ALWAYS use the MySQL user ID as the chat Firebase UID. It must match
        // the value stamped into `participantUids` on every conversation doc
        // (see buildConversationMetadata), which is also strval($user->id).
        //
        // We deliberately ignore `firebase_uid` (which can hold a phone-OTP
        // UID): if it changed after a conversation was created, the cached
        // participantUids would diverge and Firestore would deny reads with
        // "Missing or insufficient permissions". MySQL ID is stable forever.
        $uid = strval($user->id);

        return $this->auth->createCustomToken($uid)->toString();
    }

    // ── Build a deterministic conversation id ─────────────────────────────────

    /**
     * Deterministic conversation ID per (ad, participant pair). Stable across calls
     * so the buyer cannot create duplicate conversations with the same seller on the
     * same ad — re-calling the endpoint just returns the same ID.
     */
    public static function conversationId(int $adId, int $userIdA, int $userIdB): string
    {
        $low  = min($userIdA, $userIdB);
        $high = max($userIdA, $userIdB);

        return "ad{$adId}_u{$low}_u{$high}";
    }

    // ── Build the metadata payload the client uses to seed the Firestore doc ──

    /**
     * Returns the metadata the frontend needs to call Firestore's
     * setDoc(merge:true) on the conversation doc the first time a message is
     * sent. The backend itself does NOT touch Firestore here — it just returns
     * canonical participant ordering and matching Firebase UIDs so the client
     * can write a doc that complies with the security rules.
     *
     * @return array{
     *   conversation_id: string,
     *   participant_ids: array{0: string, 1: string},
     *   participant_uids: array{0: string, 1: string},
     *   ad_id: string,
     *   ad_title: string,
     *   ad_image: string|null,
     *   seller: array{id: int, name: string, avatar: string|null, firebase_uid: string},
     *   buyer:  array{id: int, name: string, firebase_uid: string},
     * }
     */
    public function buildConversationMetadata(User $buyer, Ad $ad): array
    {
        $seller = $ad->user;

        $buyerId  = (int) $buyer->id;
        $sellerId = (int) $seller->id;

        // Canonical participant order: [smaller_id, larger_id] for stable dedup.
        $participantIds = $buyerId < $sellerId
            ? [strval($buyerId), strval($sellerId)]
            : [strval($sellerId), strval($buyerId)];

        // IMPORTANT: must match the UID used by mintCustomToken() — always
        // strval($user->id), never $user->firebase_uid. Otherwise the doc's
        // participantUids would go stale if the user later sets/changes their
        // firebase_uid (e.g. via phone OTP) and Firestore would deny reads.
        $buyerUid  = strval($buyer->id);
        $sellerUid = strval($seller->id);

        $participantUids = $buyerId < $sellerId
            ? [$buyerUid, $sellerUid]
            : [$sellerUid, $buyerUid];

        $adImage = $ad->images()->orderBy('sort_order')->value('image_url');

        return [
            'conversation_id' => self::conversationId($ad->id, $buyerId, $sellerId),
            'participant_ids' => $participantIds,
            'participant_uids' => $participantUids,
            'ad_id'    => strval($ad->id),
            'ad_title' => $ad->title,
            'ad_image' => $adImage,
            'seller'   => [
                'id'           => $seller->id,
                'name'         => $seller->name,
                'avatar'       => $seller->avatar_url,
                'firebase_uid' => $sellerUid,
            ],
            'buyer'    => [
                'id'           => $buyer->id,
                'name'         => $buyer->name,
                'avatar'       => $buyer->avatar_url,
                'firebase_uid' => $buyerUid,
            ],
        ];
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
