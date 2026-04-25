<?php

namespace App\Http\Resources;

use App\Models\Ad;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property-read Ad $resource
 */
class AdListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        /** @var Ad $ad */
        $ad = $this->resource;

        /** @var AdImage|null $first */
        $first = $ad->images->first();
        /** @var Category|null $category */
        $category = $ad->category;
        /** @var City|null $city */
        $city = $ad->city;
        /** @var Region|null $region */
        $region = $ad->region;

        return [
            'id'           => $ad->id,
            'title'        => $ad->title,
            'price'        => $ad->price,
            'is_negotiable'=> $ad->is_negotiable,
            'is_free'      => $ad->is_free,
            'status'       => $ad->status->value,
            'status_label' => $ad->status->label(),
            'primary_image'=> $first ? new AdImageResource($first) : null,
            'category'     => $category ? [
                'id'      => $category->id,
                'name_ar' => $category->name_ar,
                'slug'    => $category->slug,
                'icon'    => $category->icon,
            ] : null,
            'city'         => $city ? [
                'id'      => $city->id,
                'name_ar' => $city->name_ar,
            ] : null,
            'region'       => $region ? [
                'id'      => $region->id,
                'name_ar' => $region->name_ar,
            ] : null,
            'is_boosted'   => $ad->is_boosted,
            'boosted_until'=> $ad->boosted_until,
            'published_at' => $ad->published_at,
            'created_at'   => $ad->created_at,
        ];
    }
}
