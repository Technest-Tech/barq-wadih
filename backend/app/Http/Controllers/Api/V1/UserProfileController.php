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
    public function show(User $user): JsonResponse
    {
        $activeAdsCount = Ad::where('user_id', $user->id)
            ->active()
            ->count();

        $soldAdsCount = Ad::withTrashed()
            ->where('user_id', $user->id)
            ->where('status', 'sold')
            ->count();

        $ratings = Rating::forUser($user->id)->approved()->get(['stars']);
        $total   = $ratings->count();
        $avg     = $total > 0 ? round((float) $ratings->avg('stars'), 1) : 0.0;
        $distribution = collect([5, 4, 3, 2, 1])->mapWithKeys(
            fn (int $star) => [$star => $ratings->where('stars', $star)->count()]
        )->all();

        return $this->successResponse([
            'id'             => $user->id,
            'name'           => $user->name,
            'avatar'         => $user->avatar_url,
            'cover_image'    => $user->cover_image_url,
            'bio'            => $user->bio,
            'is_verified'    => (bool) $user->is_verified,
            'is_dealer'      => (bool) $user->is_dealer,
            'avg_rating'     => $avg,
            'rating_count'   => $total,
            'rating_distribution' => $distribution,
            'active_ads_count'   => $activeAdsCount,
            'sold_ads_count'     => $soldAdsCount,
            'total_ads_count'    => $user->total_ads_count ?? ($activeAdsCount + $soldAdsCount),
            'member_since'   => $user->created_at?->toIso8601String(),
            'last_active_at' => $user->last_active_at?->toIso8601String(),
        ]);
    }

    // ── Public seller ads list ────────────────────────────────────────────────
    public function ads(Request $request, User $user): JsonResponse
    {
        $sort = $request->input('sort', 'newest');

        $query = Ad::with(['images', 'category', 'city', 'region', 'user'])
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
