<?php

namespace App\Services;

use App\Models\Ad;

/**
 * PaymentService — provider-agnostic publish-fee payment interface.
 *
 * The wizard kicks off `createIntent()` after the ad is stored in
 * `pending_payment` state, hands the user off to the PSP (or, in dev,
 * straight back to a confirm endpoint), and on success calls `confirm()`
 * to mark the ad active.
 *
 * Today: bound to MockPaymentService (auto-confirms instantly).
 * Future: bound to MoyasarPaymentService when env('PAYMENT_DRIVER') === 'moyasar'.
 */
interface PaymentService
{
    /**
     * Create a payment intent for an ad. Returns a reference + redirect URL the
     * frontend can hand off to. For the mock driver, redirect_url points to our
     * own `/payment/{ad}/confirm` callback.
     */
    public function createIntent(Ad $ad): PaymentIntent;

    /**
     * Confirm payment by reference. Returns success + provider details. Idempotent:
     * a second call against an already-paid ad returns the original result.
     */
    public function confirm(string $reference): PaymentResult;

    /**
     * Validate (or fake) a webhook payload from the PSP. Returns true when the
     * signature is acceptable for this driver. Mock returns true unconditionally.
     */
    public function verifyWebhook(string $signature, string $body): bool;

    /**
     * Identifier persisted to ads.payment_provider so detail pages can render
     * provider-specific UI (e.g. Apple Pay receipt link).
     */
    public function name(): string;
}

/**
 * Value object returned by createIntent().
 */
final class PaymentIntent
{
    public function __construct(
        public readonly string $reference,
        public readonly string $redirectUrl,
        public readonly float $amount,
        public readonly string $currency = 'SAR',
    ) {}

    public function toArray(): array
    {
        return [
            'reference'    => $this->reference,
            'redirect_url' => $this->redirectUrl,
            'amount'       => $this->amount,
            'currency'     => $this->currency,
        ];
    }
}

/**
 * Value object returned by confirm().
 */
final class PaymentResult
{
    public function __construct(
        public readonly bool $success,
        public readonly string $reference,
        public readonly ?string $errorMessage = null,
        public readonly ?string $providerReference = null,
    ) {}
}
