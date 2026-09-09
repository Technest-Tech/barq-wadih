<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

class AcceptableContent implements ValidationRule
{
    /**
     * A deliberately small, high-confidence list. It prevents obviously abusive
     * submissions without rejecting ordinary marketplace language. Reports are
     * still available for contextual abuse that no word list can identify.
     *
     * @var list<string>
     */
    private const BLOCKED_TERMS = [
        'كس امك', 'كسمك', 'ابن الكلب', 'يا حيوان', 'يا خنزير',
        'fuck you', 'motherfucker', 'nigger',
    ];

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value)) {
            return;
        }

        $normalised = mb_strtolower($value);
        $normalised = str_replace(['أ', 'إ', 'آ', 'ة', 'ى'], ['ا', 'ا', 'ا', 'ه', 'ي'], $normalised);
        $normalised = preg_replace('/[\p{P}\p{S}\s_]+/u', ' ', $normalised) ?? $normalised;

        foreach (self::BLOCKED_TERMS as $term) {
            $candidate = str_replace(['أ', 'إ', 'آ', 'ة', 'ى'], ['ا', 'ا', 'ا', 'ه', 'ي'], mb_strtolower($term));
            if (str_contains($normalised, $candidate)) {
                $fail('النص يحتوي على إساءة أو محتوى غير مسموح. عدّل النص وحاول مرة أخرى.');

                return;
            }
        }
    }
}
