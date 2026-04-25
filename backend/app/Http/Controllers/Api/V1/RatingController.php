<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\RatingResource;
use App\Models\Ad;
use App\Models\Rating;
use App\Models\User;
use App\Services\PushService;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class RatingController extends Controller
{
    use ApiResponses;

    // ── GET /ads/{ad}/ratings ─────────────────────────────────────────────────

    public function index(Ad $ad): AnonymousResourceCollection
    {
        $ratings = Rating::with(['rater', 'ad'])
            ->where('rated_user_id', $ad->user_id)
            ->where('ad_id', $ad->id)
            ->approved()
            ->latest()
            ->paginate(15);

        return RatingResource::collection($ratings);
    }

    // ── POST /ads/{ad}/ratings ────────────────────────────────────────────────

    public function store(Request $request, Ad $ad): JsonResponse
    {
        $data = $request->validate([
            'stars'           => 'required|integer|min:1|max:5',
            'comment'         => 'nullable|string|max:500',
            'pledge_accepted' => 'required|accepted',
        ]);

        // Cannot rate your own ad
        if ($ad->user_id === $request->user()->id) {
            return $this->errorResponse('لا يمكنك تقييم إعلانك الخاص', 403);
        }

        // One rating per user per ad
        $exists = Rating::where('rater_id', $request->user()->id)
            ->where('rated_user_id', $ad->user_id)
            ->where('ad_id', $ad->id)
            ->exists();

        if ($exists) {
            return $this->errorResponse('لقد قيّمت هذا البائع على هذا الإعلان مسبقاً', 409);
        }

        $rating = DB::transaction(function () use ($request, $ad, $data): Rating {
            $rating = Rating::create([
                'rater_id'        => $request->user()->id,
                'rated_user_id'   => $ad->user_id,
                'ad_id'           => $ad->id,
                'stars'           => $data['stars'],
                'comment'         => $data['comment'] ?? null,
                'pledge_accepted' => true,
                'is_approved'     => true,
            ]);

            $this->recalculateUserRating($ad->user_id);

            return $rating;
        });

        $rating->load('rater', 'ad');

        // Sprint 10: Notify the seller about the new rating
        app(PushService::class)->sendToUser(
            $ad->user_id,
            'new_rating',
            'تقييم جديد',
            "قيّمك {$request->user()->name} بـ {$data['stars']} نجوم",
            [
                'type'   => 'rating',
                'ad_id'  => $ad->id,
                'rating' => $data['stars'],
            ],
        );

        return $this->successResponse(new RatingResource($rating), 'تم إرسال تقييمك بنجاح', 201);
    }

    // ── GET /users/{user}/ratings ─────────────────────────────────────────────

    public function userRatings(User $user): AnonymousResourceCollection
    {
        $ratings = Rating::with(['rater', 'ad'])
            ->forUser($user->id)
            ->approved()
            ->latest()
            ->paginate(15);

        return RatingResource::collection($ratings);
    }

    // ── GET /users/{user}/rating-summary ──────────────────────────────────────

    public function summary(User $user): JsonResponse
    {
        $ratings = Rating::forUser($user->id)->approved()->get(['stars']);

        $total = $ratings->count();
        $avg   = $total > 0 ? round((float) $ratings->avg('stars'), 1) : 0.0;

        $distribution = collect([5, 4, 3, 2, 1])->mapWithKeys(
            fn (int $star) => [$star => $ratings->where('stars', $star)->count()]
        )->all();

        return $this->successResponse([
            'avg_rating'   => $avg,
            'rating_count' => $total,
            'distribution' => $distribution,
        ]);
    }

    // ── DELETE /ratings/{rating} ──────────────────────────────────────────────

    public function destroy(Request $request, Rating $rating): JsonResponse
    {
        if ($rating->rater_id !== $request->user()->id) {
            return $this->errorResponse('غير مصرح لك بحذف هذا التقييم', 403);
        }

        $ratedUserId = $rating->rated_user_id;

        DB::transaction(function () use ($rating, $ratedUserId): void {
            $rating->delete();
            $this->recalculateUserRating($ratedUserId);
        });

        return $this->successResponse(null, 'تم حذف التقييم');
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function recalculateUserRating(int $userId): void
    {
        $stats = Rating::where('rated_user_id', $userId)
            ->approved()
            ->selectRaw('AVG(stars) as avg_rating, COUNT(*) as rating_count')
            ->first();

        User::where('id', $userId)->update([
            'avg_rating'   => round((float) ($stats?->avg_rating ?? 0), 2),
            'rating_count' => (int) ($stats?->rating_count ?? 0),
        ]);
    }
}
