<?php

namespace App\Enums;

enum ModerationStatus: string
{
    case Approved = 'approved';
    case Flagged = 'flagged';
    case UnderReview = 'under_review';
    case Rejected = 'rejected';

    public function label(): string
    {
        return match ($this) {
            self::Approved => 'مقبول',
            self::Flagged => 'مُبلّغ عنه',
            self::UnderReview => 'قيد المراجعة',
            self::Rejected => 'مرفوض',
        };
    }
}
