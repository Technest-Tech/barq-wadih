<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\BaseController;
use App\Models\City;
use App\Models\Region;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class AdminRegionController extends BaseController
{
    /**
     * GET /api/v1/admin/regions
     *
     * All regions with cities count.
     */
    public function index(): JsonResponse
    {
        $regions = Region::withCount(['cities'])
            ->with(['cities' => fn ($q) => $q->withCount('ads')->ordered()])
            ->ordered()
            ->get()
            ->map(fn (Region $r) => [
                'id'           => $r->id,
                'name_ar'      => $r->name_ar,
                'name_en'      => $r->name_en,
                'slug'         => $r->slug,
                'is_active'    => $r->is_active,
                'sort_order'   => $r->sort_order,
                'cities_count' => $r->cities_count,
                'ads_count'    => $r->cities->sum('ads_count'),
                'cities'       => $r->cities->map(fn (City $c) => [
                    'id'         => $c->id,
                    'name_ar'    => $c->name_ar,
                    'name_en'    => $c->name_en,
                    'slug'       => $c->slug,
                    'latitude'   => $c->latitude,
                    'longitude'  => $c->longitude,
                    'is_active'  => $c->is_active,
                    'sort_order' => $c->sort_order,
                    'ads_count'  => $c->ads_count,
                ]),
            ]);

        return $this->successResponse($regions);
    }

    /**
     * GET /api/v1/admin/regions/{region}/cities
     *
     * Cities for a specific region with ads count.
     */
    public function cities(Region $region): JsonResponse
    {
        $cities = $region->cities()
            ->withCount('ads')
            ->ordered()
            ->get();

        return $this->successResponse($cities);
    }

    /**
     * POST /api/v1/admin/regions/{region}/toggle
     */
    public function toggleRegion(Region $region): JsonResponse
    {
        $region->update(['is_active' => !$region->is_active]);
        Cache::forget('regions:list');

        $status = $region->is_active ? 'تفعيل' : 'تعطيل';

        return $this->successResponse($region->fresh(), "تم {$status} المنطقة بنجاح.");
    }

    /**
     * POST /api/v1/admin/cities/{city}/toggle
     */
    public function toggleCity(City $city): JsonResponse
    {
        $city->update(['is_active' => !$city->is_active]);
        Cache::forget('regions:list');

        $status = $city->is_active ? 'تفعيل' : 'تعطيل';

        return $this->successResponse($city->fresh(), "تم {$status} المدينة بنجاح.");
    }

    /**
     * PUT /api/v1/admin/cities/{city}
     */
    public function updateCity(Request $request, City $city): JsonResponse
    {
        $data = $request->validate([
            'name_ar'    => 'sometimes|string|max:100',
            'name_en'    => 'sometimes|string|max:100',
            'latitude'   => 'nullable|numeric|between:-90,90',
            'longitude'  => 'nullable|numeric|between:-180,180',
            'sort_order' => 'integer|min:0',
        ]);

        $city->update($data);
        Cache::forget('regions:list');

        return $this->successResponse($city->fresh(), 'تم تحديث المدينة بنجاح.');
    }
}
