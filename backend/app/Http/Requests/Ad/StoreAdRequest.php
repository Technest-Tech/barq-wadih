<?php

namespace App\Http\Requests\Ad;

use App\Models\Category;
use App\Models\CategoryField;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAdRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Auth middleware handles authentication
    }

    public function rules(): array
    {
        $categoryId = (int) $this->input('category_id');

        return [
            // Core
            'category_id'    => ['required', 'integer', Rule::exists('categories', 'id')->where('is_active', true)],
            'city_id'        => ['required', 'integer', 'exists:cities,id'],
            'title'          => ['required', 'string', 'min:3', 'max:100'],
            'description'    => ['required', 'string', 'min:10', 'max:5000'],
            'price'          => ['required_if:is_free,false', 'nullable', 'numeric', 'min:0', 'max:9999999'],
            'is_negotiable'  => ['sometimes', 'boolean'],
            'is_free'        => ['sometimes', 'boolean'],
            'contact_phone'  => ['required', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'contact_whatsapp' => ['nullable', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'pledge_accepted'=> ['required', 'accepted'],

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

            // Validate required dynamic fields
            $requiredFields = CategoryField::where('category_id', $categoryId)
                ->where('is_required', true)
                ->pluck('field_key');

            /** @var array<string, mixed> $submittedFields */
            $submittedFields = (array) $this->input('fields', []);

            foreach ($requiredFields as $key) {
                if (! array_key_exists($key, $submittedFields) || blank($submittedFields[$key])) {
                    $v->errors()->add("fields.{$key}", "الحقل '{$key}' مطلوب لهذا التصنيف.");
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
            'price.required_if'       => 'السعر مطلوب للإعلانات المدفوعة.',
            'price.numeric'           => 'السعر يجب أن يكون رقماً.',
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
