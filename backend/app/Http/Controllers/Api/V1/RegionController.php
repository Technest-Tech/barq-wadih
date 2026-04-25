<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\CityResource;
use App\Http\Resources\RegionResource;
use App\Models\City;
use App\Models\Region;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class RegionController extends BaseController
{
    /**
     * GET /api/v1/regions
     * Cached for 1 hour — invalidated by AdminRegionController.
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $regions = Cache::remember('regions:list', 3600, fn () =>
                Region::query()
                    ->active()
                    ->ordered()
                    ->withCount('cities')
                    ->get()
            );
        } catch (\Throwable) {
            $regions = Region::query()
                ->active()
                ->ordered()
                ->withCount('cities')
                ->get();
        }

        return $this->successResponse(
            RegionResource::collection($regions),
            __('Retrieved regions')
        );
    }

    /**
     * GET /api/v1/regions/{slug}/cities
     * Cached for 1 hour per slug — invalidated by AdminRegionController.
     */
    public function cities(Request $request, string $slug): JsonResponse
    {
        $region = Region::query()
            ->active()
            ->where('slug', $slug)
            ->first();

        if (! $region) {
            return $this->errorResponse(__('Region not found'), 404);
        }

        try {
            $cities = Cache::remember("regions:{$slug}:cities", 3600, fn () =>
                $region->cities()
                    ->where('is_active', true)
                    ->orderBy('sort_order')
                    ->orderBy('name_ar')
                    ->get()
            );
        } catch (\Throwable) {
            $cities = $region->cities()
                ->where('is_active', true)
                ->orderBy('sort_order')
                ->orderBy('name_ar')
                ->get();
        }

        return $this->successResponse(
            CityResource::collection($cities),
            __('Retrieved cities for :region', ['region' => $region->name_en])
        );
    }

    /**
     * GET /api/v1/cities
     * Cached for 1 hour — invalidated by AdminRegionController.
     */
    public function allCities(Request $request): JsonResponse
    {
        try {
            $cities = Cache::remember('cities:all', 3600, fn () =>
                City::query()
                    ->where('is_active', true)
                    ->orderBy('sort_order')
                    ->orderBy('name_ar')
                    ->with('region')
                    ->get()
            );
        } catch (\Throwable) {
            $cities = City::query()
                ->where('is_active', true)
                ->orderBy('sort_order')
                ->orderBy('name_ar')
                ->with('region')
                ->get();
        }

        return $this->successResponse(
            CityResource::collection($cities),
            __('Retrieved all cities')
        );
    }
}
