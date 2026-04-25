<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Admin-level user list resource — includes sensitive fields not shown in public API.
 *
 * @mixin User
 */
class AdminUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                     => $this->id,
            'name'                   => $this->name,
            'email'                  => $this->email,
            'phone'                  => $this->phone,
            'avatar_url'             => $this->avatar
                ? asset('storage/' . $this->avatar)
                : null,
            'bio'                    => $this->bio,
            'role'                   => $this->role->value,
            'role_label'             => $this->role->label(),
            'locale'                 => $this->locale,
            'is_verified'            => $this->is_verified,
            'is_dealer'              => $this->is_dealer,
            'is_active'              => $this->is_active,
            'avg_rating'             => $this->avg_rating,
            'rating_count'           => $this->rating_count,
            'total_ads_count'        => $this->total_ads_count,
            'commissions_paid_count' => $this->commissions_paid_count,
            'commissions_due_count'  => $this->commissions_due_count,
            'phone_verified_at'      => $this->phone_verified_at?->toISOString(),
            'email_verified_at'      => $this->email_verified_at?->toISOString(),
            'last_active_at'         => $this->last_active_at?->toISOString(),
            'region'                 => $this->whenLoaded('region', function () {
                /** @var \App\Models\Region $region */
                $region = $this->region;
                return [
                    'id'      => $region->id,
                    'name_ar' => $region->name_ar,
                    'name_en' => $region->name_en,
                ];
            }),
            'city'                   => $this->whenLoaded('city', function () {
                /** @var \App\Models\City $city */
                $city = $this->city;
                return [
                    'id'      => $city->id,
                    'name_ar' => $city->name_ar,
                    'name_en' => $city->name_en,
                ];
            }),
            'created_at'             => $this->created_at?->toISOString(),
        ];
    }
}
