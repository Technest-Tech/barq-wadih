<?php

namespace App\Enums;

enum FieldType: string
{
    case Text        = 'text';
    case Number      = 'number';
    case Select      = 'select';
    case MultiSelect = 'multi_select';
    case Year        = 'year';
    case Boolean     = 'boolean';

    public function label(): string
    {
        return match ($this) {
            self::Text        => 'نص',
            self::Number      => 'رقم',
            self::Select      => 'اختيار',
            self::MultiSelect => 'اختيار متعدد',
            self::Year        => 'سنة',
            self::Boolean     => 'نعم/لا',
        };
    }
}
