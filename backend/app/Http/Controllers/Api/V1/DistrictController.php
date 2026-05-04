<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\DistrictResource;
use App\Models\City;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

class DistrictController extends BaseController
{
    /**
     * GET /api/v1/cities/{city}/districts
     * Cached for 1 hour per city. Returns active districts ordered for the
     * post-ad wizard's district step. An empty list signals the frontend to
     * fall back to a free-text input.
     */
    public function index(City $city): JsonResponse
    {
        $cacheKey = "cities:{$city->id}:districts";

        try {
            $districts = Cache::remember($cacheKey, 3600, fn () =>
                $city->districts()
                    ->active()
                    ->ordered()
                    ->get()
            );
        } catch (\Throwable) {
            $districts = $city->districts()
                ->active()
                ->ordered()
                ->get();
        }

        return $this->successResponse(
            DistrictResource::collection($districts),
            __('Retrieved districts for :city', ['city' => $city->name_en ?? $city->name_ar])
        );
    }
}
