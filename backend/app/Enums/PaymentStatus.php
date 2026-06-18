<?php

namespace App\Enums;

/**
 * The publish-fee payment lifecycle for a single ad. Drives the wizard's
 * Pay step gating and the ad detail badges.
 */
enum PaymentStatus: string
{
    case NotRequired = 'not_required';
    case Pending     = 'pending';
    case UnderReview = 'under_review';
    case Paid        = 'paid';
    case Failed      = 'failed';
    case Refunded    = 'refunded';

    public function label(): string
    {
        return match ($this) {
            self::NotRequired => 'لا يتطلب دفع',
            self::Pending     => 'بانتظار الدفع',
            self::UnderReview => 'قيد مراجعة التحويل',
            self::Paid        => 'مدفوع',
            self::Failed      => 'فشل الدفع',
            self::Refunded    => 'مُعاد',
        };
    }
}
