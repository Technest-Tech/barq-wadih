<?php

namespace App\Enums;

enum SettingType: string
{
    case String  = 'string';
    case Integer = 'integer';
    case Decimal = 'decimal';
    case Boolean = 'boolean';
    case Json    = 'json';

    public function label(): string
    {
        return match ($this) {
            self::String  => 'نص',
            self::Integer => 'عدد صحيح',
            self::Decimal => 'عدد عشري',
            self::Boolean => 'نعم/لا',
            self::Json    => 'JSON',
        };
    }
}
