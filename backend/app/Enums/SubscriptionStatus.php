<?php

namespace App\Enums;

enum SubscriptionStatus: string
{
    case Active    = 'active';
    case Expired   = 'expired';
    case Cancelled = 'cancelled';
    case Pending   = 'pending';

    public function label(): string
    {
        return match ($this) {
            self::Active    => 'نشط',
            self::Expired   => 'منتهي',
            self::Cancelled => 'ملغي',
            self::Pending   => 'قيد الانتظار',
        };
    }
}
