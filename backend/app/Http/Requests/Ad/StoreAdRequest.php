<?php

namespace App\Http\Requests\Ad;

use App\Models\Category;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAdRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Auth middleware handles authentication
    }

    /**
     * The merchant/individual distinction was removed — every ad is posted as
     * an individual for now. Force it here so the value is consistent no matter
     * what a client sends.
     */
    protected function prepareForValidation(): void
    {
        $this->merge(['seller_type' => 'individual']);
    }

    public function rules(): array
    {
        $categoryId = (int) $this->input('category_id');

        return [
            // Core
            'seller_type'    => ['required', 'in:individual'],
            'category_id'    => ['required', 'integer', Rule::exists('categories', 'id')->where('is_active', true)],
            'city_id'        => ['required', 'integer', 'exists:cities,id'],
            'title'          => ['required', 'string', 'min:3', 'max:100'],
            'description'    => ['required', 'string', 'min:10', 'max:5000'],
            // Price is required for "fixed" and "على السوم" (negotiable); only
            // "عند الاتصال" (price_hidden) may omit it.
            'price'          => ['nullable', 'required_unless:price_hidden,1', 'numeric', 'min:1', 'max:9999999'],
            'price_hidden'   => ['sometimes', 'boolean'],
            'is_negotiable'  => ['sometimes', 'boolean'],
            'contact_phone'  => ['nullable', 'required_if:show_phone_publicly,1', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'contact_whatsapp' => ['nullable', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'show_phone_publicly' => ['sometimes', 'boolean'],
            'pledge_accepted'=> ['required', 'accepted'],

            // Location depth
            'district_id'        => ['nullable', 'integer', 'exists:districts,id'],
            'district_name_free' => ['nullable', 'string', 'max:120'],
            'latitude'           => ['nullable', 'numeric', 'between:-90,90'],
            'longitude'          => ['nullable', 'numeric', 'between:-180,180'],

            // Images — 1 to 10
            'images'         => ['required', 'array', 'min:1', 'max:10'],
            'images.*'       => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],

            // Dynamic category fields
            'fields'         => ['sometimes', 'array'],
            'fields.*'       => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function withValidator(\Illuminate\Contracts\Validation\Validator $validator): void
    {
        $validator->after(function (\Illuminate\Contracts\Validation\Validator $v) {
            $categoryId = (int) $this->input('category_id');

            // Reject parent categories (must select a leaf)
            $isParent = Category::where('id', $categoryId)
                ->whereNull('parent_id')
                ->whereHas('children')
                ->exists();

            if ($isParent) {
                $v->errors()->add('category_id', 'يجب اختيار تصنيف فرعي وليس تصنيفاً رئيسياً.');
                return;
            }

            // Enforce required dynamic category fields (e.g. the cars fields:
            // النوع/الموديل/الممشى/اللون). Only keys defined for the category count.
            $requiredFields = \App\Models\CategoryField::where('category_id', $categoryId)
                ->where('is_required', true)
                ->get(['field_key', 'label_ar']);

            /** @var array<string, mixed> $submitted */
            $submitted = (array) $this->input('fields', []);
            foreach ($requiredFields as $field) {
                if (blank($submitted[$field->field_key] ?? null)) {
                    $v->errors()->add("fields.{$field->field_key}", "حقل {$field->label_ar} مطلوب.");
                }
            }

            // District (FK or free-text) and the map pin are all optional — the
            // required city already provides location. If a district_id is given,
            // it must belong to the selected city.
            if (! blank($this->input('district_id'))) {
                $cityId     = (int) $this->input('city_id');
                $districtId = (int) $this->input('district_id');
                $belongs = \App\Models\District::where('id', $districtId)
                    ->where('city_id', $cityId)
                    ->exists();
                if (! $belongs) {
                    $v->errors()->add('district_id', 'الحي المحدد لا ينتمي إلى المدينة المختارة.');
                }
            }
        });
    }

    public function messages(): array
    {
        return [
            'category_id.required'    => 'يرجى اختيار التصنيف.',
            'city_id.required'        => 'يرجى اختيار المدينة.',
            'title.required'          => 'عنوان الإعلان مطلوب.',
            'title.min'               => 'يجب أن يكون العنوان 3 أحرف على الأقل.',
            'title.max'               => 'لا يمكن أن يتجاوز العنوان 100 حرف.',
            'description.required'    => 'وصف الإعلان مطلوب.',
            'description.min'         => 'يجب أن يكون الوصف 10 أحرف على الأقل.',
            'price.required'          => 'السعر مطلوب ويجب أن يكون رقماً واضحاً.',
            'price.numeric'           => 'السعر يجب أن يكون رقماً.',
            'price.min'               => 'يجب أن يكون السعر أكبر من صفر.',
            'contact_phone.required'  => 'رقم التواصل مطلوب.',
            'contact_phone.regex'     => 'رقم الهاتف يجب أن يكون سعودياً صحيحاً (05xxxxxxxx).',
            'pledge_accepted.accepted'=> 'يجب الموافقة على شروط الاستخدام.',
            'images.required'         => 'يرجى إضافة صورة واحدة على الأقل.',
            'images.min'              => 'يرجى إضافة صورة واحدة على الأقل.',
            'images.max'              => 'لا يمكن إضافة أكثر من 10 صور.',
            'images.*.image'          => 'يجب أن تكون الملفات صوراً.',
            'images.*.mimes'          => 'الصور يجب أن تكون بصيغة JPG أو PNG أو WebP.',
            'images.*.max'            => 'حجم الصورة لا يتجاوز 5 ميغابايت.',
        ];
    }
}
