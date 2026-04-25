<?php

namespace App\Enums;

enum NotificationChannel: string
{
    case Push  = 'push';
    case InApp = 'in_app';
    case Both  = 'both';

    public function label(): string
    {
        return match ($this) {
            self::Push  => 'إشعار فوري',
            self::InApp => 'داخل التطبيق',
            self::Both  => 'الكل',
        };
    }
}
