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

    // ── GET /notifications/unread-count ──────────────────────────────────────

    public function unreadCount(Request $request): JsonResponse
    {
        $count = Notification::forUser($request->user()->id)
            ->unread()
            ->count();

        return $this->successResponse(['count' => $count]);
    }
}
