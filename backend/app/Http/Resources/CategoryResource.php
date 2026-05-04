<?php

namespace App\Http\Resources;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Category
 */
class CategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'              => $this->id,
            'name_ar'         => $this->name_ar,
            'name_en'         => $this->name_en,
            'slug'            => $this->slug,
            'icon'            => $this->icon,
            'image'           => $this->image,
            'description_ar'  => $this->description_ar,
            'description_en'  => $this->description_en,
            'sort_order'                      => $this->sort_order,
            'is_active'                       => $this->is_active,
            'is_free'                         => $this->is_free,
            'commission_rate'                 => $this->commission_rate,
            'publish_fee_individual'          => $this->publish_fee_individual,
            'publish_fee_dealer'              => $this->publish_fee_dealer,
            'fee_deductible_from_commission'  => $this->fee_deductible_from_commission,
            'ads_count'                       => $this->ads_count,
            'fields_count'                    => $this->whenCounted('fields'),

            // Nested children — only included when loaded
            'children' => CategoryResource::collection(
                $this->whenLoaded('children')
            ),
        ];
    }
}
