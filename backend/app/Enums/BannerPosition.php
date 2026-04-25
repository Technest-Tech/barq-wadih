<?php

namespace App\Enums;

enum BannerPosition: string
{
    case HomeTop     = 'home_top';
    case HomeMiddle  = 'home_middle';
    case CategoryTop = 'category_top';

    public function label(): string
    {
        return match ($this) {
            self::HomeTop     => 'أعلى الرئيسية',
            self::HomeMiddle  => 'وسط الرئيسية',
            self::CategoryTop => 'أعلى القسم',
        };
    }
}
