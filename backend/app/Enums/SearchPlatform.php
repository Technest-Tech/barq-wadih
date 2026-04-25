<?php

namespace App\Enums;

enum SearchPlatform: string
{
    case Web     = 'web';
    case Ios     = 'ios';
    case Android = 'android';

    public function label(): string
    {
        return match ($this) {
            self::Web     => 'ويب',
            self::Ios     => 'iOS',
            self::Android => 'أندرويد',
        };
    }
}
