<?php

namespace App\Http\Resources;

use App\Models\Rating;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Rating
 */
class RatingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'          => $this->id,
            'stars'       => $this->stars,
            'comment'     => $this->comment,
            'is_approved' => $this->is_approved,
            'rater'       => [
                'id'     => $this->rater->id,
                'name'   => $this->rater->name,
                'avatar' => $this->rater->avatar_url,
            ],
            'ad'          => $this->whenLoaded('ad', function () {
                /** @var \App\Models\Ad $ad */
                $ad = $this->ad;
                return [
                    'id'    => $ad->id,
                    'title' => $ad->title,
                ];
            }),
            'created_at'  => $this->created_at?->toISOString(),
        ];
    }
}
