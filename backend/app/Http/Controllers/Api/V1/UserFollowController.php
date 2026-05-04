<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserFollow;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserFollowController extends Controller
{
    use ApiResponses;

    // ── POST /users/{user}/follow ─────────────────────────────────────────────

    public function toggle(Request $request, User $user): JsonResponse
    {
        $followerId = $request->user()->id;

        if ($followerId === $user->id) {
            return $this->errorResponse('لا يمكنك متابعة نفسك', 422);
        }

        $existing = UserFollow::where('follower_id', $followerId)
            ->where('followed_id', $user->id)
            ->first();

        if ($existing) {
            $existing->delete();
            return $this->successResponse(
                [
                    'is_following'    => false,
                    'followers_count' => UserFollow::where('followed_id', $user->id)->count(),
                ],
                'تم إلغاء المتابعة',
            );
        }

        UserFollow::create([
            'follower_id' => $followerId,
            'followed_id' => $user->id,
        ]);

        return $this->successResponse(
            [
                'is_following'    => true,
                'followers_count' => UserFollow::where('followed_id', $user->id)->count(),
            ],
            'تمت المتابعة — سيتم إشعارك عند إعلانات جديدة',
        );
    }

    // ── GET /users/{user}/follow-status ───────────────────────────────────────

    public function status(Request $request, User $user): JsonResponse
    {
        $isFollowing = UserFollow::where('follower_id', $request->user()->id)
            ->where('followed_id', $user->id)
            ->exists();

        return $this->successResponse([
            'is_following'    => $isFollowing,
            'followers_count' => UserFollow::where('followed_id', $user->id)->count(),
        ]);
    }

    // ── GET /seller-follows ───────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $follows = UserFollow::with(['followed' => function ($q) {
            $q->withCount(['ads' => function ($q) {
                $q->where('status', 'active')
                  ->where('moderation_status', 'approved');
            }]);
        }])
            ->where('follower_id', $request->user()->id)
            ->latest('created_at')
            ->get()
            ->filter(fn (UserFollow $f) => $f->followed !== null)
            ->map(fn (UserFollow $f) => [
                'id'          => $f->id,
                'seller'      => [
                    'id'              => $f->followed->id,
                    'name'            => $f->followed->name,
                    'avatar'          => $f->followed->avatar_url,
                    'is_verified'     => (bool) $f->followed->is_verified,
                    'is_dealer'       => (bool) $f->followed->is_dealer,
                    'avg_rating'      => $f->followed->avg_rating,
                    'rating_count'    => $f->followed->rating_count,
                    'total_ads_count' => $f->followed->total_ads_count,
                    'active_ads_count' => $f->followed->ads_count ?? 0,
                ],
                'created_at' => $f->created_at?->toIso8601String(),
            ])
            ->values();

        return $this->successResponse($follows);
    }
}
