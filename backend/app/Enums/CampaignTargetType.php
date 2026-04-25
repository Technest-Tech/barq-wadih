<?php

namespace App\Enums;

enum CampaignTargetType: string
{
    case All           = 'all';
    case City          = 'city';
    case Category      = 'category';
    case SpecificUsers = 'specific_users';

    public function label(): string
    {
        return match ($this) {
            self::All           => 'الجميع',
            self::City          => 'مدينة محددة',
            self::Category      => 'قسم محدد',
            self::SpecificUsers => 'مستخدمون محددون',
        };
    }
}
