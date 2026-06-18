<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AdStatus;
use App\Enums\PaymentStatus;
use App\Http\Resources\AdResource;
use App\Models\Ad;
use App\Services\AdService;
use App\Services\ImageService;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Drives the publish-fee payment lifecycle for a single ad. The wizard's
 * Pay step calls `init` to obtain a redirect URL, then `confirm` after
 * the user returns from the PSP. `webhook` receives async PSP callbacks.
 *
 * While the PSP integration is not yet live, sellers pay the publish fee by
 * manual bank transfer and submit a screenshot via `uploadProof`; an admin then
 * reviews and approves it (see AdminPaymentProofController).
 */
class AdPaymentController extends BaseController
{
    public function __construct(
        private readonly PaymentService $payments,
        private readonly AdService $adService,
        private readonly ImageService $imageService,
    ) {}

    /**
     * POST /api/v1/ads/{ad}/payment/proof
     * Owner-only. Accepts a screenshot of the manual bank transfer, stores it,
     * and moves the ad's payment into `under_review` for admin verification.
     * The ad itself stays in PendingPayment until an admin approves the proof.
     */
    public function uploadProof(Request $request, Ad $ad): JsonResponse
    {
        $this->authorize('update', $ad);

        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $this->errorResponse(__('Payment already completed for this ad.'), 422);
        }

        if ((float) ($ad->payment_amount ?? 0) <= 0) {
            return $this->errorResponse(__('No payment is required for this ad.'), 422);
        }

        $request->validate([
            'proof' => 'required|image|mimes:jpeg,jpg,png,webp|max:8192',
        ]);

        // Drop any previous proof so we don't accumulate orphaned files.
        if ($ad->payment_proof_url) {
            $this->imageService->delete($ad->payment_proof_url);
        }

        $path = $this->imageService->store($request->file('proof'), 'payment-proofs');

        $ad->update([
            'payment_provider'          => 'bank_transfer',
            'payment_status'            => PaymentStatus::UnderReview->value,
            'payment_proof_url'         => $this->imageService->url($path),
            'payment_proof_uploaded_at' => now(),
            'payment_review_note'       => null,
        ]);

        return $this->successResponse(
            new AdResource($ad->fresh()),
            __('Transfer receipt uploaded. It is now under review.')
        );
    }

    /**
     * POST /api/v1/ads/{ad}/payment/init
     * Owner-only. Creates a payment intent against the configured driver and
     * returns the redirect URL the wizard should hand off to.
     */
    public function init(Ad $ad): JsonResponse
    {
        $this->authorize('update', $ad);

        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $this->errorResponse(__('Payment already completed for this ad.'), 422);
        }

        if ((float) ($ad->payment_amount ?? 0) <= 0) {
            return $this->errorResponse(__('No payment is required for this ad.'), 422);
        }

        $intent = $this->payments->createIntent($ad);

        $ad->update([
            'payment_provider'  => $this->payments->name(),
            'payment_reference' => $intent->reference,
            'payment_status'    => PaymentStatus::Pending->value,
        ]);

        return $this->successResponse([
            'intent' => $intent->toArray(),
            'ad_id'  => $ad->id,
        ], __('Payment intent created.'));
    }

    /**
     * POST /api/v1/ads/{ad}/payment/confirm
     * Owner-only. Verifies the reference with the driver, marks the ad paid,
     * and transitions it from `pending_payment` → `active` (publishing it).
     */
    public function confirm(Request $request, Ad $ad): JsonResponse
    {
        $this->authorize('update', $ad);

        $reference = (string) ($request->input('ref') ?? $ad->payment_reference);
        if ($reference === '') {
            return $this->errorResponse(__('Missing payment reference.'), 422);
        }

        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $this->successResponse(new AdResource($ad->fresh()), __('Payment already confirmed.'));
        }

        $result = $this->payments->confirm($reference);

        if (! $result->success) {
            $ad->update(['payment_status' => PaymentStatus::Failed->value]);
            return $this->errorResponse($result->errorMessage ?? __('Payment failed.'), 402);
        }

        $updated = $this->adService->markPaid($ad, [
            'reference'         => $result->reference,
            'provider_reference'=> $result->providerReference ?? $result->reference,
        ]);

        return $this->successResponse(new AdResource($updated), __('Payment confirmed and ad published.'));
    }

    /**
     * POST /api/v1/payment/webhook/moyasar
     * Public — verified by signature. Stub for future async PSP callbacks; the
     * mock driver accepts all signatures and the moyasar driver throws until
     * wired up. We swallow errors and 200-OK so providers don't retry forever.
     */
    public function webhook(Request $request): JsonResponse
    {
        $signature = (string) $request->header('X-Moyasar-Signature', '');
        $body      = $request->getContent();

        try {
            $valid = $this->payments->verifyWebhook($signature, $body);
        } catch (\Throwable) {
            $valid = false;
        }

        if (! $valid) {
            return $this->errorResponse(__('Invalid webhook signature.'), 401);
        }

        // TODO: parse payload and call confirm() once moyasar is wired up.
        return $this->successResponse(['received' => true]);
    }
}
