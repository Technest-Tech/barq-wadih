<?php

namespace App\Services;

use App\Models\Ad;

/**
 * Skeleton for the eventual Moyasar integration. Bound when
 * config('services.payment.driver') === 'moyasar'. Throws until the
 * concrete API calls are wired up — keeping the structure visible so the
 * future swap is mechanical.
 */
class MoyasarPaymentService implements PaymentService
{
    public function createIntent(Ad $ad): PaymentIntent
    {
        throw new \RuntimeException('MoyasarPaymentService::createIntent not yet implemented.');
    }

    public function confirm(string $reference): PaymentResult
    {
        throw new \RuntimeException('MoyasarPaymentService::confirm not yet implemented.');
    }

    public function verifyWebhook(string $signature, string $body): bool
    {
        throw new \RuntimeException('MoyasarPaymentService::verifyWebhook not yet implemented.');
    }

    public function name(): string
    {
        return 'moyasar';
    }
}
