<?php

namespace App\Enums;

enum ReportReason: string
{
    case Fake = 'fake';
    case Spam = 'spam';
    case ProhibitedContent = 'prohibited_content';
    case WrongCategory = 'wrong_category';
    case DuplicateAd = 'duplicate_ad';
    case ScamOrFraud = 'scam_or_fraud';
    case InappropriateImages = 'inappropriate_images';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Fake => 'إعلان مزيف',
            self::Spam => 'إعلان مزعج',
            self::ProhibitedContent => 'محتوى محظور',
            self::WrongCategory => 'تصنيف خاطئ',
            self::DuplicateAd => 'إعلان مكرر',
            self::ScamOrFraud => 'احتيال',
            self::InappropriateImages => 'صور غير لائقة',
            self::Other => 'أخرى',
        };
    }
}
