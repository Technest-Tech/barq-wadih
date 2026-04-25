<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\AdListResource;
use App\Models\Ad;
use App\Models\Favorite;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class FavoriteController extends Controller
{
    use ApiResponses;

    // ── GET /favorites ────────────────────────────────────────────────────────

    public function index(Request $request): AnonymousResourceCollection
    {
        $ads = Ad::join('favorites', 'favorites.ad_id', '=', 'ads.id')
            ->where('favorites.user_id', $request->user()->id)
            ->where('ads.status', 'active')
            ->with(['category', 'city', 'region', 'images'])
            ->orderByDesc('favorites.created_at')
            ->select('ads.*')
            ->paginate(20);

        return AdListResource::collection($ads);
    }

    // ── POST /ads/{ad}/favorite ───────────────────────────────────────────────

    public function toggle(Request $request, Ad $ad): JsonResponse
    {
        $userId = $request->user()->id;

        $existing = Favorite::where('user_id', $userId)
            ->where('ad_id', $ad->id)
            ->first();

        if ($existing) {
            $existing->delete();
            $ad->decrement('favorites_count');

            return $this->successResponse(['is_favorited' => false], 'تم إزالة الإعلان من المفضلة');
        }

        Favorite::create([
            'user_id' => $userId,
            'ad_id'   => $ad->id,
        ]);
        $ad->increment('favorites_count');

        return $this->successResponse(['is_favorited' => true], 'تم إضافة الإعلان إلى المفضلة');
    }

    // ── GET /ads/{ad}/favorite-status ────────────────────────────────────────

    public function status(Request $request, Ad $ad): JsonResponse
    {
        $isFavorited = Favorite::where('user_id', $request->user()->id)
            ->where('ad_id', $ad->id)
            ->exists();

        return $this->successResponse(['is_favorited' => $isFavorited]);
    }
}
