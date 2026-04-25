<?php

namespace App\Enums;

enum DeviceType: string
{
    case Ios = 'ios';
    case Android = 'android';
    case Web = 'web';

    public function label(): string
    {
        return match ($this) {
            self::Ios     => 'iOS',
            self::Android => 'أندرويد',
            self::Web     => 'ويب',
        };
    }
}
