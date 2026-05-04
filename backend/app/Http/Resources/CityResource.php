<?php

namespace App\Http\Resources;

use App\Models\City;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin City
 */
class CityResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'              => $this->id,
            'name_ar'         => $this->name_ar,
            'name_en'         => $this->name_en,
            'slug'            => $this->slug,
            'latitude'        => $this->latitude,
            'longitude'       => $this->longitude,
            'ads_count'       => $this->ads_count,
            // Number of districts seeded for this city. Populated by the
            // RegionController via `withCount('districts')`. Drives the wizard's
            // free-text fallback when no districts are seeded.
            'districts_count' => $this->districts_count,
            'region'          => $this->whenLoaded('region', function () {
                /** @var \App\Models\Region $region */
                $region = $this->region;
                return [
                    'id'      => $region->id,
                    'name_ar' => $region->name_ar,
                    'name_en' => $region->name_en,
                    'slug'    => $region->slug,
                ];
            }),
        ];
    }
}
