<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\AdResource;
use App\Models\Ad;
use App\Models\AdBoost;
use App\Services\BoostService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BoostController extends BaseController
{
    public function __construct(private readonly BoostService $boostService) {}

    // ── Public: Boost Config ──────────────────────────────────────────────────

    public function config(): JsonResponse
    {
        return $this->successResponse($this->boostService->getConfig());
    }

    // ── Authenticated: Premium Boost ──────────────────────────────────────────

    public function boost(Request $request, Ad $ad): JsonResponse
    {
        $this->authorize('boost', $ad);

        $this->boostService->boostPremium($ad, $request->user());

        return $this->successResponse(
            new AdResource($ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region', 'user'])),
            'تم ترقية الإعلان بنجاح! ⚡'
        );
    }

    // ── Authenticated: Refresh ────────────────────────────────────────────────

    public function refresh(Request $request, Ad $ad): JsonResponse
    {
        $this->authorize('boost', $ad);

        $this->boostService->refresh($ad, $request->user());

        return $this->successResponse(
            new AdResource($ad->fresh(['images', 'fieldValues.field', 'category', 'city', 'region', 'user'])),
            'تم تحديث الإعلان بنجاح! 🔄'
        );
    }

    // ── Authenticated: Boost History ──────────────────────────────────────────

    public function history(Request $request, Ad $ad): JsonResponse
    {
        $this->authorize('boost', $ad);

        $boosts = AdBoost::where('ad_id', $ad->id)
            ->latest('boosted_at')
            ->limit(20)
            ->get()
            ->map(fn (AdBoost $b) => [
                'id'         => $b->id,
                'boost_type' => $b->boost_type->value,
                'label'      => $b->boost_type->label(),
                'boosted_at' => $b->boosted_at?->toISOString(),
                'expires_at' => $b->expires_at?->toISOString(),
                'is_expired' => $b->isExpired(),
            ]);

        return $this->successResponse($boosts);
    }
}
