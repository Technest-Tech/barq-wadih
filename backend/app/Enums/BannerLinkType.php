<?php

namespace App\Enums;

enum BannerLinkType: string
{
    case Ad        = 'ad';
    case Whatsapp  = 'whatsapp';
    case Url       = 'url';
    case None      = 'none';

    public function label(): string
    {
        return match ($this) {
            self::Ad       => 'إعلان',
            self::Whatsapp => 'واتساب',
            self::Url      => 'رابط خارجي',
            self::None     => 'بدون رابط',
        };
    }
}
