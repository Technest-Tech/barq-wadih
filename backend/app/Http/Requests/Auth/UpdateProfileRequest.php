<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name'      => ['sometimes', 'string', 'min:2', 'max:100'],
            'bio'       => ['sometimes', 'nullable', 'string', 'max:500'],
            'locale'    => ['sometimes', 'string', 'in:ar,en'],
            'region_id' => ['sometimes', 'nullable', 'integer', 'exists:regions,id'],
            'city_id'   => ['sometimes', 'nullable', 'integer', 'exists:cities,id'],
        ];
    }
}
