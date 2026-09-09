<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\NotificationResource;
use App\Models\Notification;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class NotificationController extends Controller
{
    use ApiResponses;

    // ── GET /notifications ────────────────────────────────────────────────────

    public function index(Request $request): AnonymousResourceCollection
    {
        $notifications = Notification::forUser($request->user()->id)
            ->latest()
            ->paginate(20);

        return NotificationResource::collection($notifications);
    }

    // ── POST /notifications/{notification}/read ──────────────────────────────

    public function markRead(Request $request, Notification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) {
            return $this->errorResponse('غير مصرح', 403);
        }

        if (!$notification->is_read) {
            $notification->update([
                'is_read' => true,
                'read_at' => now(),
            ]);
        }

        return $this->successResponse(new NotificationResource($notification));
    }

    // ── POST /notifications/read-all ─────────────────────────────────────────

    public function markAllRead(Request $request): JsonResponse
    {
        Notification::forUser($request->user()->id)
            ->unread()
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);

        return $this->successResponse(null, 'تم تعيين جميع الإشعارات كمقروءة');
    }

    // ── POST /notifications/read-by ──────────────────────────────────────────

    /**
     * Marks every unread notification matching a filter as read.
     *
     * Opening the thing a notification points at — a conversation, an ad — is
     * the user telling us they have seen it, but the client only knows the
     * subject (conversation id / ad id), never the notification row ids. This
     * lets it clear exactly that slice instead of either leaving the badge
     * stuck or nuking every other unread notification with read-all.
     */
    public function markReadBy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type'            => ['nullable', 'string', 'max:100'],
            'conversation_id' => ['nullable', 'string', 'max:191'],
            'ad_id'           => ['nullable', 'integer'],
        ]);

        $type           = $data['type'] ?? null;
        $conversationId = $data['conversation_id'] ?? null;
        $adId           = $data['ad_id'] ?? null;

        if ($type === null && $conversationId === null && $adId === null) {
            return $this->errorResponse('حدد الإشعارات المراد تعيينها كمقروءة', 422);
        }

        $query = Notification::forUser($request->user()->id)->unread();

        if ($type !== null) {
            $query->where('type', $type);
        }

        if ($conversationId !== null) {
            $query->where('data->conversation_id', $conversationId);
        }

        if ($adId !== null) {
            // `data->ad_id` is written as an int by some senders and as a
            // string by others, and the JSON comparison is type-sensitive on
            // SQLite — so match either shape.
            $query->where(fn ($q) => $q
                ->where('data->ad_id', $adId)
                ->orWhere('data->ad_id', (string) $adId));
        }

        $updated = $query->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        return $this->successResponse(['updated' => $updated]);
    }

    // ── GET /notifications/unread-count ──────────────────────────────────────

    public function unreadCount(Request $request): JsonResponse
    {
        $count = Notification::forUser($request->user()->id)
            ->unread()
            ->count();

        return $this->successResponse(['count' => $count]);
    }
}
