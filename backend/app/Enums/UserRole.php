<?php

namespace App\Enums;

enum UserRole: string
{
    case User = 'user';
    case Admin = 'admin';
    case SuperAdmin = 'super_admin';

    public function label(): string
    {
        return match ($this) {
            self::User => 'مستخدم',
            self::Admin => 'مشرف',
            self::SuperAdmin => 'مشرف عام',
        };
    }
}
