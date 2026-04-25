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
            'phone'                 => ['required', 'string', 'regex:/^\+966[0-9]{9}$/', 'unique:users,phone'],
            'email'                 => ['nullable', 'email', 'unique:users,email', 'max:191'],
            'password'              => ['nullable', 'string', 'min:8', 'confirmed'],
            'region_id'             => ['nullable', 'integer', 'exists:regions,id'],
            'city_id'               => ['nullable', 'integer', 'exists:cities,id'],
            'locale'                => ['nullable', 'string', 'in:ar,en'],
        ];
    }

    public function messages(): array
    {
        return [
            'phone.regex'   => 'رقم الجوال يجب أن يبدأ بـ +966 ويتكون من 9 أرقام.',
            'phone.unique'  => 'رقم الجوال مسجل مسبقاً.',
            'email.unique'  => 'البريد الإلكتروني مسجل مسبقاً.',
            'name.required' => 'الاسم مطلوب.',
            'phone.required'=> 'رقم الجوال مطلوب.',
        ];
    }
}
