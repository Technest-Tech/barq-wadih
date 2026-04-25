<?php

namespace App\Http\Resources;

use App\Models\Banner;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Banner
 */
class BannerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'               => $this->id,
            'title'            => $this->title,
            'image_url'        => $this->image_url,
            'image_url_mobile' => $this->image_url_mobile,
            'link_type'        => $this->link_type?->value,
            'link_ad_id'       => $this->link_ad_id,
            'link_whatsapp'    => $this->link_whatsapp,
            'link_url'         => $this->link_url,
            'position'         => $this->position?->value,
            'sort_order'       => $this->sort_order,
        ];
    }
}
