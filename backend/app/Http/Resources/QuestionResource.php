<?php

namespace App\Http\Resources;

use App\Models\AdQuestion;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin AdQuestion
 */
class QuestionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'         => $this->id,
            'body'       => $this->body,
            'user'       => [
                'id'     => $this->user->id,
                'name'   => $this->user->name,
                'avatar' => $this->user->avatar_url ?? null,
            ],
            'replies'    => QuestionResource::collection($this->whenLoaded('replies')),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
