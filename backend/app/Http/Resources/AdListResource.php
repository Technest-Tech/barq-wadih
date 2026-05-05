<?php

namespace App\Http\Resources;

use App\Models\Ad;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
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
        /** @var User|null $user */
        $user = $ad->user;

        return [
            'id'           => $ad->id,
            'user_id'      => $ad->user_id,
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
            'user'         => $user ? [
                'id'           => $user->id,
                'name'         => $user->name,
                'avatar'       => $user->avatar_url,
                'is_verified'  => (bool) $user->is_verified,
                'is_dealer'    => (bool) $user->is_dealer,
                'avg_rating'   => $user->avg_rating,
                'rating_count' => $user->rating_count,
            ] : null,
            'published_at' => $ad->published_at,
            'created_at'   => $ad->created_at,
        ];
    }
}
