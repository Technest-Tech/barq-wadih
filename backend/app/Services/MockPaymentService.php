<?php

namespace App\Services;

use App\Models\Ad;
use Illuminate\Support\Str;

/**
 * Default implementation used in dev/staging until Moyasar is wired up.
 *
 * - createIntent(): generates a reference and returns the wizard's own
 *   /pay/[adId] route as the redirect URL — the frontend's PaymentLauncher
 *   then calls confirm() directly to simulate a successful charge.
 * - confirm(): unconditionally succeeds.
 * - verifyWebhook(): unconditionally accepts.
 */
class MockPaymentService implements PaymentService
{
    public function createIntent(Ad $ad): PaymentIntent
    {
        $reference = 'mock_' . Str::random(20);
        $amount    = (float) ($ad->payment_amount ?? 0);

        return new PaymentIntent(
            reference: $reference,
            redirectUrl: url("/api/v1/ads/{$ad->id}/payment/confirm?ref={$reference}"),
            amount: $amount,
        );
    }

    public function confirm(string $reference): PaymentResult
    {
        return new PaymentResult(
            success: true,
            reference: $reference,
            providerReference: $reference,
        );
    }

    public function verifyWebhook(string $signature, string $body): bool
    {
        return true;
    }

    public function name(): string
    {
        return 'mock';
    }
}
