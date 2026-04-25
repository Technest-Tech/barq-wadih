<?php

namespace App\Enums;

enum ReportStatus: string
{
    case Pending   = 'pending';
    case Reviewed  = 'reviewed';
    case Resolved  = 'resolved';
    case Dismissed = 'dismissed';

    public function label(): string
    {
        return match ($this) {
            self::Pending   => 'قيد الانتظار',
            self::Reviewed  => 'تمت المراجعة',
            self::Resolved  => 'تم الحل',
            self::Dismissed => 'تم الرفض',
        };
    }
}
