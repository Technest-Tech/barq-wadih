<?php

namespace App\Enums;

enum BillingCycle: string
{
    case Monthly   = 'monthly';
    case Quarterly = 'quarterly';
    case Yearly    = 'yearly';

    public function label(): string
    {
        return match ($this) {
            self::Monthly   => 'شهري',
            self::Quarterly => 'ربع سنوي',
            self::Yearly    => 'سنوي',
        };
    }
}
