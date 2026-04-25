<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Card = 'card';
    case Mada = 'mada';
    case Sadad = 'sadad';
    case ApplePay = 'apple_pay';
    case BankTransfer = 'bank_transfer';

    public function label(): string
    {
        return match ($this) {
            self::Card => 'بطاقة ائتمان',
            self::Mada => 'مدى',
            self::Sadad => 'سداد',
            self::ApplePay => 'Apple Pay',
            self::BankTransfer => 'تحويل بنكي',
        };
    }
}
