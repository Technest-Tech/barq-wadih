<?php

namespace App\Enums;

enum CommissionStatus: string
{
    case NotApplicable = 'not_applicable';
    case Pending = 'pending';
    case Paid = 'paid';

    public function label(): string
    {
        return match ($this) {
            self::NotApplicable => 'لا ينطبق',
            self::Pending => 'معلّق',
            self::Paid => 'مدفوع',
        };
    }
}
