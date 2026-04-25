<?php

namespace App\Enums;

enum BoostType: string
{
    case Refresh = 'refresh';
    case Premium = 'premium';

    public function label(): string
    {
        return match ($this) {
            self::Refresh => 'تحديث',
            self::Premium => 'ترقية مميزة',
        };
    }
}
