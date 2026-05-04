<?php

namespace App\Enums;

enum AdStatus: string
{
    case Active = 'active';
    case Sold = 'sold';
    case Expired = 'expired';
    case PendingReview = 'pending_review';
    case PendingPayment = 'pending_payment';
    case Rejected = 'rejected';
    case Deleted = 'deleted';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'نشط',
            self::Sold => 'مُباع',
            self::Expired => 'منتهي',
            self::PendingReview => 'قيد المراجعة',
            self::PendingPayment => 'بانتظار الدفع',
            self::Rejected => 'مرفوض',
            self::Deleted => 'محذوف',
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::Active => 'success',
            self::Sold => 'info',
            self::Expired => 'warning',
            self::PendingReview => 'warning',
            self::PendingPayment => 'warning',
            self::Rejected => 'danger',
            self::Deleted => 'danger',
        };
    }
}
