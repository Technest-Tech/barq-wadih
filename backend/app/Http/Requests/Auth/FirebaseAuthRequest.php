<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class FirebaseAuthRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'firebase_id_token' => ['required', 'string', 'min:100'],
            'name'              => ['nullable', 'string', 'min:2', 'max:100'],
            'locale'            => ['nullable', 'string', 'in:ar,en'],
        ];
    }

    public function messages(): array
    {
        return [
            'firebase_id_token.required' => 'رمز التحقق مطلوب.',
            'firebase_id_token.min'      => 'رمز التحقق غير صالح.',
        ];
    }
}
