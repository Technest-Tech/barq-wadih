<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Admin-specific report resource.
 *
 * @mixin \App\Models\Report
 */
class AdminReportResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'            => $this->id,
            'reason'        => $this->reason?->value,
            'reason_label'  => $this->reason?->label(),
            'description'   => $this->description,
            'status'        => $this->status?->value,
            'status_label'  => $this->status?->label(),
            'admin_action'  => $this->admin_action?->value,
            'admin_action_label' => $this->admin_action?->label(),
            'admin_note'    => $this->admin_note,
            'resolved_at'   => $this->resolved_at?->toISOString(),

            // ── Reporter ────────────────────────────────────────────────
            'reporter' => $this->whenLoaded('reporter', fn () => [
                'id'         => $this->reporter->id,
                'name'       => $this->reporter->name,
                'avatar_url' => $this->reporter->avatar_url,
                'phone'      => $this->reporter->phone,
                'email'      => $this->reporter->email,
            ]),

            // ── Reported Ad ─────────────────────────────────────────────
            'ad' => $this->whenLoaded('ad', fn () => $this->ad ? [
                'id'                => $this->ad->id,
                'title'             => $this->ad->title,
                'price'             => (float) $this->ad->price,
                'status'            => $this->ad->status?->value,
                'status_label'      => $this->ad->status?->label(),
                'moderation_status' => $this->ad->moderation_status?->value,
                'primary_image'     => $this->ad->images?->first()?->url,
                'category'          => $this->ad->category ? [
                    'id'      => $this->ad->category->id,
                    'name_ar' => $this->ad->category->name_ar,
                ] : null,
                'user' => $this->ad->user ? [
                    'id'          => $this->ad->user->id,
                    'name'        => $this->ad->user->name,
                    'avatar_url'  => $this->ad->user->avatar_url,
                    'phone'       => $this->ad->user->phone,
                    'is_verified' => $this->ad->user->is_verified ?? false,
                ] : null,
                'created_at' => $this->ad->created_at?->toISOString(),
            ] : null),

            // ── Admin who resolved ──────────────────────────────────────
            'admin' => $this->whenLoaded('admin', fn () => $this->admin ? [
                'id'   => $this->admin->id,
                'name' => $this->admin->name,
            ] : null),

            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
