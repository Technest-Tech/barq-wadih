<?php

namespace App\Http\Resources;

use App\Models\Ad;
use App\Models\AdFieldValue;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
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
        /** @var \App\Models\District|null $district */
        $district = $ad->district;

        // ── Privacy gates ────────────────────────────────────────────────────
        // The wizard lets sellers hide their phone or their price from the
        // public detail page. Owners (and admins, via the AdminAdResource) always
        // see the underlying values; everyone else gets nulls.
        $showPhone = $isOwner || (bool) $ad->show_phone_publicly;
        $showPrice = $isOwner || ! (bool) $ad->price_hidden;

        return [
            'id'               => $ad->id,
            'title'            => $ad->title,
            'description'      => $ad->description,
            'price'            => $showPrice ? $ad->price : null,
            'price_hidden'     => (bool) $ad->price_hidden,
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
            'district'         => $district ? [
                'id'      => $district->id,
                'name_ar' => $district->name_ar,
                'name_en' => $district->name_en,
                'slug'    => $district->slug,
            ] : null,
            'district_name_free' => $ad->district_name_free,
            'latitude'         => $ad->latitude,
            'longitude'        => $ad->longitude,
            'show_phone_publicly' => (bool) $ad->show_phone_publicly,
            'user'             => $user ? [
                'id'              => $user->id,
                'name'            => $user->name,
                'avatar'          => $user->avatar_url,
                'bio'             => $user->bio,
                'is_verified'     => (bool) $user->is_verified,
                'is_dealer'       => (bool) $user->is_dealer,
                'avg_rating'      => $user->avg_rating,
                'rating_count'    => $user->rating_count,
                'total_ads_count' => $user->total_ads_count,
                'member_since'    => $user->created_at?->toIso8601String(),
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

            'contact_phone'    => $showPhone ? $ad->contact_phone : null,
            'contact_whatsapp' => $showPhone ? $ad->contact_whatsapp : null,

            'views_count'      => $ad->views_count,
            'favorites_count'  => $ad->favorites_count,

            'commission_amount'=> $isOwner ? $ad->commission_amount : null,
            'payment_status'   => $ad->payment_status,
            'payment_amount'   => $isOwner ? $ad->payment_amount : null,
            'payment_provider' => $isOwner ? $ad->payment_provider : null,
            'paid_at'          => $isOwner ? $ad->paid_at : null,
            'payment_proof_url'   => $isOwner ? $ad->payment_proof_url : null,
            'payment_review_note' => $isOwner ? $ad->payment_review_note : null,

            'published_at'     => $ad->published_at,
            'expires_at'       => $ad->expires_at,
            'created_at'       => $ad->created_at,
            'updated_at'       => $ad->updated_at,
        ];
    }
}
