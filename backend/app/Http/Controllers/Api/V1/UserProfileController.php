<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\AdListResource;
use App\Models\Ad;
use App\Models\Rating;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserProfileController extends BaseController
{
    // ── Public seller profile ─────────────────────────────────────────────────
    public function show(Request $request, User $user): JsonResponse
    {
        $activeAdsCount = Ad::where('user_id', $user->id)
            ->active()
            ->count();

        $soldAdsCount = Ad::withTrashed()
            ->where('user_id', $user->id)
            ->where('status', 'sold')
            ->count();

        $ratings = Rating::forUser($user->id)->approved()->get(['stars']);
        $total = $ratings->count();
        $avg = $total > 0 ? round((float) $ratings->avg('stars'), 1) : 0.0;
        $distribution = collect([5, 4, 3, 2, 1])->mapWithKeys(
            fn (int $star) => [$star => $ratings->where('stars', $star)->count()],
        )->all();

        // Public route, but the clients still send their Sanctum token — resolve
        // it so the profile can tell the viewer whether the review form is open
        // to them and, if they already wrote one, which review is theirs.
        $viewer = $request->user('sanctum');

        $myReview = $viewer
            ? Rating::where('rater_id', $viewer->id)
                ->where('rated_user_id', $user->id)
                ->whereNull('ad_id')
                ->first(['id', 'stars', 'comment', 'created_at'])
            : null;

        $canReview = $viewer !== null
            && $viewer->id !== $user->id
            && $myReview === null
            && ! $viewer->cannotInteractWith($user);

        return $this->successResponse([
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'profile_url' => $user->profile_url,
            'avatar' => $user->avatar_url,
            'cover_image' => $user->cover_image_url,
            'bio' => $user->bio,
            'is_verified' => (bool) $user->is_verified,
            'verified_at' => $user->verified_at?->toIso8601String(),
            'is_dealer' => (bool) $user->is_dealer,
            'avg_rating' => $avg,
            'rating_count' => $total,
            'rating_distribution' => $distribution,
            'active_ads_count' => $activeAdsCount,
            'sold_ads_count' => $soldAdsCount,
            'total_ads_count' => $user->total_ads_count ?? ($activeAdsCount + $soldAdsCount),
            'member_since' => $user->created_at?->toIso8601String(),
            'last_active_at' => $user->last_active_at?->toIso8601String(),
            'can_review' => $canReview,
            'my_review' => $myReview ? [
                'id' => $myReview->id,
                'stars' => $myReview->stars,
                'comment' => $myReview->comment,
                'created_at' => $myReview->created_at?->toIso8601String(),
            ] : null,
        ]);
    }

    // ── Public seller ads list ────────────────────────────────────────────────
    public function ads(Request $request, User $user): JsonResponse
    {
        $sort = $request->input('sort', 'newest');

        $query = Ad::with(['primaryImage', 'category', 'city', 'region', 'user'])
            ->withCount('images')
            ->where('user_id', $user->id)
            ->active();

        if ($sort === 'price_asc') {
            $query->orderBy('price');
        } elseif ($sort === 'price_desc') {
            $query->orderByDesc('price');
        } else {
            $query->orderByDesc('published_at')->orderByDesc('created_at');
        }

        $ads = $query->paginate(20);

        return $this->paginatedResponse(AdListResource::collection($ads));
    }
}
