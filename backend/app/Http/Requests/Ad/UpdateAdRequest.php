<?php

namespace App\Http\Requests\Ad;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAdRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // AdPolicy handles ownership check in controller
    }

    public function rules(): array
    {
        return [
            'title'           => ['sometimes', 'string', 'min:3', 'max:100'],
            'description'     => ['sometimes', 'string', 'min:10', 'max:5000'],
            'price'           => ['sometimes', 'nullable', 'numeric', 'min:0', 'max:9999999'],
            'is_negotiable'   => ['sometimes', 'boolean'],
            'is_free'         => ['sometimes', 'boolean'],
            'city_id'         => ['sometimes', 'integer', 'exists:cities,id'],
            'contact_phone'   => ['sometimes', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'contact_whatsapp'=> ['sometimes', 'nullable', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],

            // New images to append (optional)
            'images'          => ['sometimes', 'array', 'max:10'],
            'images.*'        => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],

            // Image IDs to remove (optional)
            'remove_image_ids'=> ['sometimes', 'array'],
            'remove_image_ids.*' => ['integer', 'exists:ad_images,id'],

            // Dynamic fields (partial update OK)
            'fields'          => ['sometimes', 'array'],
            'fields.*'        => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'contact_phone.regex'     => 'رقم الهاتف يجب أن يكون سعودياً صحيحاً (05xxxxxxxx).',
            'images.*.image'          => 'يجب أن تكون الملفات صوراً.',
            'images.*.max'            => 'حجم الصورة لا يتجاوز 5 ميغابايت.',
        ];
    }
}
