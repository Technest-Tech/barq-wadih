<?php

namespace App\Http\Controllers\Api\V1;

use App\Models\Ad;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatController extends BaseController
{
    public function __construct(private readonly ChatService $chatService) {}

    // ── GET /api/v1/chat/token ────────────────────────────────────────────────
    // Mint a Firebase custom token so web users can sign into Firestore.

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
    // List the authenticated user's conversations, sorted by latest message.

    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user          = $request->user();
        $conversations = $this->chatService->listConversations($user);

        return $this->successResponse(data: $conversations);
    }

    // ── POST /api/v1/chat/conversations ───────────────────────────────────────
    // Create or find an existing conversation for a given ad.

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'ad_id' => ['required', 'integer', 'exists:ads,id'],
        ]);

        /** @var User $buyer */
        $buyer = $request->user();

        /** @var Ad $ad */
        $ad = Ad::with('user', 'images')->findOrFail($request->integer('ad_id'));

        // Prevent chatting with yourself
        if ($ad->user_id === $buyer->id) {
            return $this->errorResponse(
                message: 'لا يمكنك محادثة إعلانك الخاص.',
                code: 422
            );
        }

        // Prevent messaging on inactive ads
        if ($ad->status !== 'active') {
            return $this->errorResponse(
                message: 'هذا الإعلان غير متاح للمراسلة حالياً.',
                code: 422
            );
        }

        $result = $this->chatService->findOrCreateConversation($buyer, $ad);

        return $this->successResponse(
            data: [
                'conversation_id' => $result['conversation_id'],
                'is_new'          => $result['is_new'],
                'ad'              => [
                    'id'     => $ad->id,
                    'title'  => $ad->title,
                    'price'  => $ad->price,
                    'is_free'=> $ad->is_free,
                ],
                'seller' => [
                    'id'     => $ad->user->id,
                    'name'   => $ad->user->name,
                    'avatar' => $ad->user->avatar,
                ],
            ],
            message: $result['is_new'] ? 'تم إنشاء المحادثة.' : 'تم فتح المحادثة.',
            code: $result['is_new'] ? 201 : 200
        );
    }

    // ── POST /api/v1/chat/conversations/{id}/notify ───────────────────────────
    // Client calls this after sending a message to trigger FCM push.

    public function notify(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'receiver_id'     => ['required', 'integer', 'exists:users,id'],
            'message_preview' => ['required', 'string', 'max:200'],
        ]);

        /** @var User $sender */
        $sender = $request->user();

        $this->chatService->notifyNewMessage(
            conversationId: $id,
            receiverId:     $request->integer('receiver_id'),
            messagePreview: $request->string('message_preview'),
            sender:         $sender
        );

        return $this->successResponse(message: 'تم إرسال الإشعار.');
    }
}
