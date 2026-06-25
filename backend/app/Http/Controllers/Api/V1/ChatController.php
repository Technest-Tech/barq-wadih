<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AdStatus;
use App\Models\Ad;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatController extends BaseController
{
    public function __construct(private readonly ChatService $chatService) {}

    // ── GET /api/v1/chat/token ────────────────────────────────────────────────
    // Mint a Firebase custom token so web/mobile can sign into Firestore.

    public function token(Request $request): JsonResponse
    {
        /** @var User $user */
        $user  = $request->user();
        $token = $this->chatService->mintCustomToken($user);

        return $this->successResponse(
            data: ['firebase_token' => $token],
        );
    }

    // ── GET /api/v1/chat/conversations ────────────────────────────────────────
    // Deprecated: clients now read directly from Firestore via real-time listeners.
    // Kept as a no-op endpoint so older clients don't 404.

    public function index(Request $request): JsonResponse
    {
        return $this->successResponse(data: []);
    }

    // ── POST /api/v1/chat/conversations ───────────────────────────────────────
    // Validate the ad and return the metadata the client needs to seed the
    // Firestore conversation doc (deterministic id + canonical participant
    // ordering). The actual Firestore write happens client-side under the
    // user's Firebase Auth session.

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'ad_id' => ['required', 'integer', 'exists:ads,id'],
        ]);

        /** @var User $buyer */
        $buyer = $request->user();

        /** @var Ad $ad */
        $ad = Ad::with('user', 'images')->findOrFail($request->integer('ad_id'));

        if ($ad->user_id === $buyer->id) {
            return $this->errorResponse(
                message: 'لا يمكنك محادثة إعلانك الخاص.',
                code: 422
            );
        }

        if ($ad->status !== AdStatus::Active) {
            return $this->errorResponse(
                message: 'هذا الإعلان غير متاح للمراسلة حالياً.',
                code: 422
            );
        }

        $meta = $this->chatService->buildConversationMetadata($buyer, $ad);

        return $this->successResponse(
            data: [
                'conversation_id'  => $meta['conversation_id'],
                'is_new'           => true, // client treats every call as idempotent setDoc(merge:true)
                'participant_ids'  => $meta['participant_ids'],
                'participant_uids' => $meta['participant_uids'],
                'ad' => [
                    'id'      => $ad->id,
                    'title'   => $ad->title,
                    'price'   => $ad->price,
                    'is_free' => $ad->is_free,
                    'image'   => $meta['ad_image'],
                ],
                'seller' => $meta['seller'],
                'buyer'  => $meta['buyer'],
            ],
            message: 'تم فتح المحادثة.',
            code: 200
        );
    }

    // ── POST /api/v1/chat/conversations/{id}/notify ───────────────────────────

    public function notify(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'receiver_id'     => ['required', 'integer', 'exists:users,id'],
            // Accept long messages: the preview is truncated below rather than
            // rejected, so a long chat message still triggers a notification.
            'message_preview' => ['required', 'string'],
        ]);

        /** @var User $sender */
        $sender = $request->user();

        $this->chatService->notifyNewMessage(
            conversationId: $id,
            receiverId:     $request->integer('receiver_id'),
            messagePreview: mb_substr($request->string('message_preview'), 0, 200),
            sender:         $sender
        );

        return $this->successResponse(message: 'تم إرسال الإشعار.');
    }
}
