<?php

namespace App\Enums;

enum AdminAction: string
{
    case NoAction   = 'no_action';
    case AdRemoved  = 'ad_removed';
    case UserWarned = 'user_warned';
    case UserBanned = 'user_banned';

    public function label(): string
    {
        return match ($this) {
            self::NoAction   => 'بدون إجراء',
            self::AdRemoved  => 'تم حذف الإعلان',
            self::UserWarned => 'تم تحذير المستخدم',
            self::UserBanned => 'تم حظر المستخدم',
        };
    }
}
