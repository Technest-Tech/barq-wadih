<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Full admin user detail resource — includes nested ads, payments, and ratings.
 *
 * @mixin User
 */
class AdminUserDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            // ── Profile ─────────────────────────────────────────────────
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
            'firebase_uid'           => $this->firebase_uid ? '••••' . substr($this->firebase_uid, -4) : null,

            // ── Stats ───────────────────────────────────────────────────
            'avg_rating'             => $this->avg_rating,
            'rating_count'           => $this->rating_count,
            'total_ads_count'        => $this->total_ads_count,
            'commissions_paid_count' => $this->commissions_paid_count,
            'commissions_due_count'  => $this->commissions_due_count,

            // ── Dates ───────────────────────────────────────────────────
            'phone_verified_at'      => $this->phone_verified_at?->toISOString(),
            'email_verified_at'      => $this->email_verified_at?->toISOString(),
            'last_active_at'         => $this->last_active_at?->toISOString(),
            'created_at'             => $this->created_at?->toISOString(),
            'updated_at'             => $this->updated_at?->toISOString(),

            // ── Location ────────────────────────────────────────────────
            'region'                 => $this->whenLoaded('region', function () {
                /** @var \App\Models\Region $region */
                $region = $this->region;
                return [
                    'id'      => $region->id,
                    'name_ar' => $region->name_ar,
                    'name_en' => $region->name_en,
                    'slug'    => $region->slug,
                ];
            }),
            'city'                   => $this->whenLoaded('city', function () {
                /** @var \App\Models\City $city */
                $city = $this->city;
                return [
                    'id'      => $city->id,
                    'name_ar' => $city->name_ar,
                    'name_en' => $city->name_en,
                    'slug'    => $city->slug,
                ];
            }),

            // ── Nested: Recent Ads ──────────────────────────────────────
            'ads' => $this->whenLoaded('ads', function () {
                return $this->ads->map(fn ($ad) => [
                    'id'          => $ad->id,
                    'title'       => $ad->title,
                    'price'       => $ad->price,
                    'status'      => $ad->status->value,
                    'status_label' => $ad->status->label(),
                    'category'    => $ad->category ? [
                        'id'      => $ad->category->id,
                        'name_ar' => $ad->category->name_ar,
                    ] : null,
                    'city'        => $ad->city ? [
                        'id'      => $ad->city->id,
                        'name_ar' => $ad->city->name_ar,
                    ] : null,
                    'views_count' => $ad->views_count,
                    'created_at'  => $ad->created_at?->toISOString(),
                    'expires_at'  => $ad->expires_at?->toISOString(),
                ]);
            }),

            // ── Nested: Commission Payments ─────────────────────────────
            'commission_payments' => $this->whenLoaded('commissionPayments', function () {
                return $this->commissionPayments->map(fn ($payment) => [
                    'id'             => $payment->id,
                    'amount'         => $payment->amount,
                    'status'         => $payment->status->value,
                    'payment_method' => $payment->payment_method?->value,
                    'ad_id'          => $payment->ad_id,
                    'paid_at'        => $payment->paid_at?->toISOString(),
                    'created_at'     => $payment->created_at?->toISOString(),
                ]);
            }),

            // ── Nested: Ratings Received ────────────────────────────────
            'ratings_received' => $this->whenLoaded('ratingsReceived', function () {
                return $this->ratingsReceived->map(fn ($rating) => [
                    'id'         => $rating->id,
                    'score'      => $rating->score,
                    'comment'    => $rating->comment,
                    'rater'      => $rating->rater ? [
                        'id'   => $rating->rater->id,
                        'name' => $rating->rater->name,
                    ] : null,
                    'created_at' => $rating->created_at?->toISOString(),
                ]);
            }),

            // ── Devices count ───────────────────────────────────────────
            'devices_count' => $this->whenLoaded('devices', fn () => $this->devices->count()),
        ];
    }
}
