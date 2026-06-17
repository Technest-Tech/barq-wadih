<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name'                  => ['required', 'string', 'min:2', 'max:100'],
            'phone'                 => ['nullable', 'string', 'regex:/^\+(?:966[0-9]{9}|20(10|11|12|15)[0-9]{8})$/', 'unique:users,phone'],
            'email'                 => ['required', 'email', 'unique:users,email', 'max:191'],
            'password'              => ['nullable', 'string', 'min:8', 'confirmed'],
            'region_id'             => ['nullable', 'integer', 'exists:regions,id'],
            'city_id'               => ['nullable', 'integer', 'exists:cities,id'],
            'locale'                => ['nullable', 'string', 'in:ar,en'],
        ];
    }

    public function messages(): array
    {
        return [
            'phone.regex'   => 'رقم الجوال غير صالح (مثال: +9665XXXXXXXX أو +201XXXXXXXXX).',
            'phone.unique'  => 'رقم الجوال مسجل مسبقاً.',
            'email.unique'  => 'البريد الإلكتروني مسجل مسبقاً.',
            'name.required' => 'الاسم مطلوب.',
            'phone.required'=> 'رقم الجوال مطلوب.',
        ];
    }
}
