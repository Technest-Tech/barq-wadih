<?php

namespace App\Http\Requests\Ad;

use App\Models\Ad;
use App\Models\Category;
use App\Models\CategoryField;
use App\Rules\AcceptableContent;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Arr;
use Illuminate\Validation\Rule;

class UpdateAdRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // AdPolicy handles ownership check in controller
    }

    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'string', 'min:3', 'max:100', new AcceptableContent],
            'description' => ['sometimes', 'string', 'min:10', 'max:5000', new AcceptableContent],
            // "على السوم" accepts 0 (stored as null); a fixed price must be > 0.
            'price' => [
                'sometimes',
                'nullable',
                'numeric',
                $this->staysNegotiable() ? 'min:0' : 'min:1',
                'max:9999999',
            ],
            'is_negotiable' => ['sometimes', 'boolean'],
            // Without these the seller can never switch an existing ad to or
            // from "عند الاتصال" / "مجاني": the app sends them, validated()
            // dropped them, and the price kept showing as first published.
            'price_hidden' => ['sometimes', 'boolean'],
            'is_free' => ['sometimes', 'boolean'],
            'category_id' => ['sometimes', 'integer', Rule::exists('categories', 'id')->where('is_active', true)],
            'city_id' => ['sometimes', 'integer', 'exists:cities,id'],
            'district_id' => ['sometimes', 'nullable', 'integer', 'exists:districts,id'],
            'district_name_free' => ['sometimes', 'nullable', 'string', 'max:120'],
            'latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],
            'contact_phone' => ['sometimes', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'contact_whatsapp' => ['sometimes', 'nullable', 'string', 'regex:/^(05|\+9665)[0-9]{8}$/'],
            'show_phone_publicly' => ['sometimes', 'boolean'],

            // New images to append (optional)
            'images' => ['sometimes', 'array', 'max:10'],
            'images.*' => ['required', 'file', 'mimes:jpg,jpeg,png,webp,heic,heif', 'max:5120'],

            // Image IDs to remove (optional)
            'remove_image_ids' => ['sometimes', 'array'],
            'remove_image_ids.*' => ['integer', 'exists:ad_images,id'],

            // The gallery in the order the seller arranged it; the first entry
            // is the ad's cover photo. Each entry is either an existing image's
            // id or "new:<i>" pointing at the i-th file in `images` — so a photo
            // added during this edit can be dropped anywhere in the order.
            'image_order' => ['sometimes', 'array'],
            // Left untyped on purpose: multipart sends every entry as a
            // string, JSON clients send existing ids as integers, and the
            // "new:<i>" tokens are strings either way. Format is checked in
            // validateImageOrder().
            'image_order.*' => ['required'],

            // Dynamic fields (partial update OK)
            'fields' => ['sometimes', 'array'],
            'fields.*' => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $v) {
            $ad = $this->route('ad');
            if (! $ad instanceof Ad) {
                return;
            }

            $requestedRemovalIds = array_values(array_unique(array_map(
                'intval',
                (array) $this->input('remove_image_ids', []),
            )));
            $ownedRemovalCount = $ad->images()
                ->whereIn('id', $requestedRemovalIds)
                ->count();

            if ($ownedRemovalCount !== count($requestedRemovalIds)) {
                $v->errors()->add(
                    'remove_image_ids',
                    'إحدى الصور المحددة لا تنتمي إلى هذا الإعلان.',
                );
            }

            $this->validateCategoryChange($v, $ad);
            $this->validateImageOrder($v, $ad, $requestedRemovalIds);

            $newImages = $this->file('images', []);
            $newImageCount = is_array($newImages)
                ? count($newImages)
                : ($newImages ? 1 : 0);
            $finalImageCount = $ad->images()->count()
                - $ownedRemovalCount
                + $newImageCount;

            if ($finalImageCount < 1) {
                $v->errors()->add(
                    'images',
                    'يجب أن يحتوي الإعلان على صورة واحدة على الأقل.',
                );
            } elseif ($finalImageCount > 10) {
                $v->errors()->add(
                    'images',
                    'لا يمكن أن يحتوي الإعلان على أكثر من 10 صور.',
                );
            }
        });
    }

    /**
     * A category switch re-homes the ad's specs: the old category's dynamic
     * values are wiped (see AdService::update), so the new category's required
     * fields have to arrive with the same request or the ad ends up incomplete.
     */
    private function validateCategoryChange(Validator $v, Ad $ad): void
    {
        if (! $this->filled('category_id')) {
            return;
        }

        $categoryId = (int) $this->input('category_id');
        if ($categoryId === $ad->category_id) {
            return;
        }

        $isParent = Category::where('id', $categoryId)
            ->whereNull('parent_id')
            ->whereHas('children')
            ->exists();

        if ($isParent) {
            $v->errors()->add('category_id', 'يجب اختيار تصنيف فرعي وليس تصنيفاً رئيسياً.');

            return;
        }

        $requiredFields = CategoryField::where('category_id', $categoryId)
            ->where('is_required', true)
            ->get(['field_key', 'label_ar']);

        /** @var array<string, mixed> $submitted */
        $submitted = (array) $this->input('fields', []);
        foreach ($requiredFields as $field) {
            if (blank($submitted[$field->field_key] ?? null)) {
                $v->errors()->add("fields.{$field->field_key}", "حقل {$field->label_ar} مطلوب.");
            }
        }
    }

    /**
     * @param  array<int, int>  $requestedRemovalIds
     */
    private function validateImageOrder(Validator $v, Ad $ad, array $requestedRemovalIds): void
    {
        if (! $this->has('image_order')) {
            return;
        }

        $newImageCount = count(Arr::wrap($this->file('images', [])));

        $existingIds = [];
        foreach ((array) $this->input('image_order', []) as $token) {
            $token = (string) $token;

            if (str_starts_with($token, 'new:')) {
                $index = (int) substr($token, 4);
                if ($index < 0 || $index >= $newImageCount) {
                    $v->errors()->add('image_order', 'ترتيب الصور لا يطابق الصور المرفوعة.');

                    return;
                }

                continue;
            }

            if (! ctype_digit($token)) {
                $v->errors()->add('image_order', 'ترتيب الصور غير صالح.');

                return;
            }

            $existingIds[] = (int) $token;
        }

        $existingIds = array_values(array_unique($existingIds));

        if (array_intersect($existingIds, $requestedRemovalIds) !== []) {
            $v->errors()->add('image_order', 'لا يمكن ترتيب صورة محذوفة.');

            return;
        }

        $ownedCount = $ad->images()->whereIn('id', $existingIds)->count();
        if ($ownedCount !== count($existingIds)) {
            $v->errors()->add('image_order', 'إحدى الصور المحددة لا تنتمي إلى هذا الإعلان.');
        }
    }

    /**
     * Whether this edit leaves the ad "على السوم".
     *
     * The client may send a price without resending is_negotiable — every rule
     * here is `sometimes` — so an absent flag has to fall back to what the ad
     * already is, otherwise editing the price of a negotiable ad would reject
     * the 0 that publishing it accepted.
     */
    private function staysNegotiable(): bool
    {
        if ($this->has('is_negotiable')) {
            return $this->boolean('is_negotiable');
        }

        $ad = $this->route('ad');

        return $ad instanceof Ad && $ad->is_negotiable;
    }

    public function messages(): array
    {
        return [
            'price.min' => $this->staysNegotiable()
                ? 'لا يمكن أن يكون السعر بالسالب.'
                : 'يجب أن يكون السعر أكبر من صفر.',
            'contact_phone.regex' => 'رقم الهاتف يجب أن يكون سعودياً صحيحاً (05xxxxxxxx).',
            'images.*.mimes' => 'الصور يجب أن تكون بصيغة JPG أو PNG أو WebP أو HEIC.',
            'images.*.max' => 'حجم الصورة لا يتجاوز 5 ميغابايت.',
        ];
    }
}
