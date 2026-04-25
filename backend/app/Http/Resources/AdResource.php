<?php

namespace App\Http\Resources;

use App\Models\Ad;
use App\Models\AdFieldValue;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
use App\Services\BoostService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @property-read Ad $resource
 */
class AdResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        /** @var Ad $ad */
        $ad = $this->resource;
        $isOwner = auth()->id() === $ad->user_id;

        /** @var Category|null $category */
        $category = $ad->category;
        /** @var City|null $city */
        $city = $ad->city;
        /** @var Region|null $region */
        $region = $ad->region;
        /** @var User|null $user */
        $user = $ad->user;

        return [
            'id'               => $ad->id,
            'title'            => $ad->title,
            'description'      => $ad->description,
            'price'            => $ad->price,
            'is_negotiable'    => $ad->is_negotiable,
            'is_free'          => $ad->is_free,
            'status'           => $ad->status->value,
            'status_label'     => $ad->status->label(),
            'status_color'     => $ad->status->color(),
            'moderation_status'=> $ad->moderation_status->value,

            'category'         => $category ? [
                'id'      => $category->id,
                'name_ar' => $category->name_ar,
                'name_en' => $category->name_en,
                'slug'    => $category->slug,
                'icon'    => $category->icon,
            ] : null,
            'city'             => $city ? [
                'id'        => $city->id,
                'name_ar'   => $city->name_ar,
                'latitude'  => $city->latitude,
                'longitude' => $city->longitude,
            ] : null,
            'region'           => $region ? [
                'id'      => $region->id,
                'name_ar' => $region->name_ar,
                'slug'    => $region->slug,
            ] : null,
            'user'             => $user ? [
                'id'           => $user->id,
                'name'         => $user->name,
                'avatar'       => $user->avatar_url,
                'avg_rating'   => $user->avg_rating,
                'rating_count' => $user->rating_count,
            ] : null,

            'images'           => AdImageResource::collection($ad->images),

            'field_values'     => (function () use ($ad): array {
                $result = [];
                foreach ($ad->fieldValues as $fv) {
                    /** @var \App\Models\AdFieldValue $fv */
                    /** @var \App\Models\CategoryField|null $field */
                    $field    = $fv->field;
                    $result[] = [
                        'field_key'  => $field?->field_key,
                        'label_ar'   => $field?->label_ar,
                        'label_en'   => $field?->label_en,
                        'field_type' => $field?->field_type?->value,
                        'value'      => $fv->casted_value,
                    ];
                }
                return $result;
            })(),

            'contact_phone'    => $ad->contact_phone,
            'contact_whatsapp' => $ad->contact_whatsapp,

            'views_count'      => $ad->views_count,
            'favorites_count'  => $ad->favorites_count,
            'is_boosted'       => $ad->is_boosted,
            'boosted_until'    => $ad->boosted_until,

            // Sprint 13: Boost eligibility (owner-only)
            'can_boost'        => $isOwner && $request->user() ? app(BoostService::class)->canBoost($ad, $request->user())[0] : null,
            'can_refresh'      => $isOwner && $request->user() ? app(BoostService::class)->canRefresh($ad, $request->user())[0] : null,
            'next_refresh_at'  => $isOwner && $request->user() ? (app(BoostService::class)->canRefresh($ad, $request->user())[2] ?? null) : null,

            'commission_amount'=> $isOwner ? $ad->commission_amount : null,

            'published_at'     => $ad->published_at,
            'expires_at'       => $ad->expires_at,
            'created_at'       => $ad->created_at,
            'updated_at'       => $ad->updated_at,
        ];
    }
}
