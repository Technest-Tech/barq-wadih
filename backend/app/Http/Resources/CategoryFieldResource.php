<?php

namespace App\Http\Resources;

use App\Models\CategoryField;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin CategoryField
 */
class CategoryFieldResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'             => $this->id,
            'field_key'      => $this->field_key,
            'label_ar'       => $this->label_ar,
            'label_en'       => $this->label_en,
            'field_type'     => $this->field_type->value,
            'options'        => $this->options,
            'is_required'    => $this->is_required,
            'is_filterable'  => $this->is_filterable,
            'sort_order'     => $this->sort_order,
            'placeholder_ar' => $this->placeholder_ar,
            'placeholder_en' => $this->placeholder_en,
        ];
    }
}
