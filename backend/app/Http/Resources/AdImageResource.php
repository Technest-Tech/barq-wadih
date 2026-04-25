<?php

namespace App\Http\Resources;

use App\Models\AdImage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin AdImage
 */
class AdImageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'            => $this->id,
            'image_url'     => $this->image_url,
            'thumbnail_url' => $this->thumbnail_url ?? $this->image_url,
            'sort_order'    => $this->sort_order,
            'width'         => $this->width,
            'height'        => $this->height,
        ];
    }
}
