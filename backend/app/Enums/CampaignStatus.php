<?php

namespace App\Enums;

enum CampaignStatus: string
{
    case Draft     = 'draft';
    case Scheduled = 'scheduled';
    case Sent      = 'sent';
    case Failed    = 'failed';

    public function label(): string
    {
        return match ($this) {
            self::Draft     => 'مسودة',
            self::Scheduled => 'مجدولة',
            self::Sent      => 'تم الإرسال',
            self::Failed    => 'فشل الإرسال',
        };
    }
}
