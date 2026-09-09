<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class MarketingTrackingEventRequest extends FormRequest
{
    private const EVENT_NAMES = [
        'APP_INSTALL',
        'APP_OPEN',
        'SIGN_UP',
        'LOGIN',
        'VIEW_CONTENT',
        'SEARCH',
        'ADD_TO_WISHLIST',
        'PURCHASE',
        'CUSTOM_EVENT_1',
        'CUSTOM_EVENT_2',
    ];

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'event_name' => ['required', 'string', Rule::in(self::EVENT_NAMES)],
            'event_id' => ['required', 'string', 'max:200'],
            // Snapchat accepts Unix timestamps with second or millisecond
            // granularity and recommends the latter for better precision.
            'event_time' => ['required', 'integer', 'between:1000000000,9999999999999'],
            'app_data' => ['required', 'array'],
            'app_data.app_id' => ['required', 'string', 'max:200'],
            'app_data.advertiser_tracking_enabled' => ['required', 'boolean'],
            'app_data.extinfo' => ['required', 'array', 'size:16'],
            'app_data.extinfo.*' => ['nullable'],
            'custom_data' => ['sometimes', 'array'],
            'custom_data.content_ids' => ['sometimes', 'array', 'max:20'],
            'custom_data.content_ids.*' => ['string', 'max:200'],
            'custom_data.content_name' => ['sometimes', 'string', 'max:500'],
            'custom_data.content_category' => ['sometimes', 'string', 'max:200'],
            'custom_data.content_type' => ['sometimes', 'string', 'max:100'],
            'custom_data.currency' => ['sometimes', 'string', 'size:3'],
            'custom_data.value' => ['sometimes', 'numeric', 'min:0'],
            'custom_data.search_string' => ['sometimes', 'string', 'max:500'],
            'custom_data.order_id' => ['sometimes', 'string', 'max:200'],
            'custom_data.event_tag' => ['sometimes', 'string', 'max:100'],
            'custom_data.status' => ['sometimes', 'string', 'max:100'],
            'custom_data.custom_fields' => ['sometimes', 'array', 'max:20'],
            'custom_data.custom_fields.*' => ['nullable'],
        ];
    }
}
