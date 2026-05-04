<?php

namespace App\Http\Resources;

use App\Models\District;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin District
 */
class DistrictResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'        => $this->id,
            'name_ar'   => $this->name_ar,
            'name_en'   => $this->name_en,
            'slug'      => $this->slug,
            'latitude'  => $this->latitude,
            'longitude' => $this->longitude,
            'city_id'   => $this->city_id,
            'region_id' => $this->region_id,
        ];
    }
}
