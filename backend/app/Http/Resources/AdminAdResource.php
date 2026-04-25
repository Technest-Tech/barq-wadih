<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Admin-specific ad resource with moderation fields.
 *
 * @mixin \App\Models\Ad
 */
class AdminAdResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                => $this->id,
            'title'             => $this->title,
            'description'       => $this->description,
            'price'             => (float) $this->price,
            'is_negotiable'     => $this->is_negotiable,
            'is_free'           => $this->is_free,

            // ── Status ──────────────────────────────────────────────────
            'status'            => $this->status?->value,
            'status_label'      => $this->status?->label(),
            'moderation_status' => $this->moderation_status?->value,
            'moderation_label'  => $this->moderation_status?->label(),
            'moderation_note'   => $this->moderation_note,

            // ── Commission ──────────────────────────────────────────────
            'commission_amount' => (float) ($this->commission_amount ?? 0),
            'commission_status' => $this->commission_status?->value,

            // ── Contact ─────────────────────────────────────────────────
            'contact_phone'     => $this->contact_phone,
            'contact_whatsapp'  => $this->contact_whatsapp,

            // ── Stats ───────────────────────────────────────────────────
            'views_count'       => $this->views_count ?? 0,
            'favorites_count'   => $this->favorites_count ?? 0,
            'chats_count'       => $this->chats_count ?? 0,
            'reports_count'     => $this->whenCounted('reports'),

            // ── Boost ───────────────────────────────────────────────────
            'is_boosted'        => $this->is_boosted,
            'boosted_until'     => $this->boosted_until?->toISOString(),

            // ── Relations ───────────────────────────────────────────────
            'user' => $this->whenLoaded('user', fn () => [
                'id'          => $this->user->id,
                'name'        => $this->user->name,
                'avatar_url'  => $this->user->avatar_url,
                'phone'       => $this->user->phone,
                'email'       => $this->user->email,
                'is_verified' => $this->user->is_verified ?? false,
                'is_dealer'   => $this->user->is_dealer ?? false,
                'role'        => $this->user->role,
            ]),

            'category' => $this->whenLoaded('category', fn () => [
                'id'      => $this->category->id,
                'name_ar' => $this->category->name_ar,
                'name_en' => $this->category->name_en,
            ]),

            'city' => $this->whenLoaded('city', fn () => [
                'id'      => $this->city->id,
                'name_ar' => $this->city->name_ar,
                'name_en' => $this->city->name_en,
            ]),

            'region' => $this->whenLoaded('region', fn () => [
                'id'      => $this->region->id,
                'name_ar' => $this->region->name_ar,
                'name_en' => $this->region->name_en,
            ]),

            'images' => $this->whenLoaded('images', fn () =>
                $this->images->map(fn ($img) => [
                    'id'         => $img->id,
                    'url'        => $img->url,
                    'sort_order' => $img->sort_order,
                ])
            ),

            'field_values' => $this->whenLoaded('fieldValues', fn () =>
                $this->fieldValues->map(fn ($fv) => [
                    'field_key'  => $fv->field?->field_key,
                    'label_ar'   => $fv->field?->label_ar,
                    'value'      => $fv->value,
                ])
            ),

            'reports' => $this->whenLoaded('reports', fn () =>
                $this->reports->map(fn ($r) => [
                    'id'          => $r->id,
                    'reason'      => $r->reason?->value,
                    'reason_label'=> $r->reason?->label(),
                    'description' => $r->description,
                    'status'      => $r->status?->value,
                    'status_label'=> $r->status?->label(),
                    'reporter'    => $r->reporter ? ['id' => $r->reporter->id, 'name' => $r->reporter->name] : null,
                    'admin_note'  => $r->admin_note,
                    'created_at'  => $r->created_at?->toISOString(),
                ])
            ),

            // ── Timestamps ──────────────────────────────────────────────
            'pledge_accepted'   => $this->pledge_accepted,
            'published_at'      => $this->published_at?->toISOString(),
            'expires_at'        => $this->expires_at?->toISOString(),
            'sale_declared_at'  => $this->sale_declared_at?->toISOString(),
            'created_at'        => $this->created_at?->toISOString(),
            'updated_at'        => $this->updated_at?->toISOString(),
            'deleted_at'        => $this->deleted_at?->toISOString(),
        ];
    }
}
