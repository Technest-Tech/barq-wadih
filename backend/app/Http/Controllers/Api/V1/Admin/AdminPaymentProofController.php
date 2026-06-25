<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\PaymentStatus;
use App\Http\Controllers\Api\V1\BaseController;
use App\Jobs\SendCommissionReviewNotificationJob;
use App\Models\Ad;
use App\Services\AdService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Admin review of manual bank-transfer receipts for the ad publish fee.
 *
 * While the PSP integration is not yet live, sellers upload a screenshot of
 * their bank transfer (see AdPaymentController::uploadProof). This controller
 * lets an admin inspect those receipts and approve (publishing the ad) or
 * reject them (sending the seller back to re-upload).
 */
class AdminPaymentProofController extends BaseController
{
    public function __construct(private readonly AdService $adService) {}

    /**
     * GET /api/v1/admin/payment-proofs
     * Paginated list of ads with a bank-transfer payment. Defaults to those
     * awaiting review (payment_status = under_review); filterable by status.
     */
    public function index(Request $request): JsonResponse
    {
        $status = (string) $request->query('status', PaymentStatus::UnderReview->value);

        $query = Ad::query()
            ->with(['user:id,name,avatar,phone,email', 'category:id,name_ar', 'city:id,name_ar'])
            ->whereNotNull('payment_proof_url');

        if ($status !== 'all') {
            $query->where('payment_status', $status);
        }

        if ($q = $request->query('q')) {
            $query->where(function ($sub) use ($q) {
                $sub->where('title', 'LIKE', "%{$q}%")
                    ->orWhere('id', $q)
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'LIKE', "%{$q}%")->orWhere('phone', 'LIKE', "%{$q}%"));
            });
        }

        $query->orderByDesc('payment_proof_uploaded_at');

        $paginated = $query->paginate($request->integer('per_page', 20));
        $items = $paginated->getCollection()->map(fn (Ad $ad) => $this->transform($ad));

        return $this->successResponse([
            'data'       => $items,
            'pagination' => [
                'current_page' => $paginated->currentPage(),
                'last_page'    => $paginated->lastPage(),
                'per_page'     => $paginated->perPage(),
                'total'        => $paginated->total(),
            ],
        ]);
    }

    /**
     * GET /api/v1/admin/payment-proofs/pending-count
     * Lightweight badge counter for the sidebar.
     */
    public function pendingCount(): JsonResponse
    {
        return $this->successResponse([
            'count' => Ad::where('payment_status', PaymentStatus::UnderReview->value)
                ->whereNotNull('payment_proof_url')
                ->count(),
        ]);
    }

    /**
     * POST /api/v1/admin/payment-proofs/{ad}/approve
     * Confirms the after-sale commission transfer. The ad stays Sold.
     */
    public function approve(Ad $ad): JsonResponse
    {
        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $this->successResponse($this->transform($ad), __('Payment already confirmed.'));
        }

        if ($ad->payment_proof_url === null) {
            return $this->errorResponse(__('No transfer receipt was uploaded for this ad.'), 422);
        }

        $updated = $this->adService->markCommissionPaid($ad, [
            'reference' => $ad->payment_reference ?? ('bank_transfer:' . $ad->id),
        ]);

        $updated->update(['payment_review_note' => null]);

        SendCommissionReviewNotificationJob::dispatch($ad->id, true)->onQueue('notifications');

        return $this->successResponse(
            $this->transform($updated->fresh(['user', 'category', 'city'])),
            __('Commission transfer approved.')
        );
    }

    /**
     * POST /api/v1/admin/payment-proofs/{ad}/reject
     * Rejects the receipt with a reason; the seller can re-upload a new one.
     */
    public function reject(Request $request, Ad $ad): JsonResponse
    {
        $request->validate([
            'reason' => 'required|string|max:500',
        ]);

        if ($ad->payment_status === PaymentStatus::Paid->value) {
            return $this->errorResponse(__('Payment already completed for this ad.'), 422);
        }

        $reason = (string) $request->input('reason');

        $ad->update([
            'payment_status'      => PaymentStatus::Failed->value,
            'payment_review_note' => $reason,
        ]);

        SendCommissionReviewNotificationJob::dispatch($ad->id, false, $reason)->onQueue('notifications');

        return $this->successResponse(
            $this->transform($ad->fresh(['user', 'category', 'city'])),
            __('Transfer receipt rejected.')
        );
    }

    /**
     * Flatten an ad into the payment-proof review payload.
     */
    private function transform(Ad $ad): array
    {
        return [
            'id'                 => $ad->id,
            'title'              => $ad->title,
            'payment_status'     => $ad->payment_status,
            'payment_amount'     => (float) ($ad->payment_amount ?? 0),
            'payment_proof_url'  => $ad->payment_proof_url,
            'payment_review_note'=> $ad->payment_review_note,
            'uploaded_at'        => $ad->payment_proof_uploaded_at?->toIso8601String(),
            'paid_at'            => $ad->paid_at?->toIso8601String(),
            'created_at'         => $ad->created_at?->toIso8601String(),
            'category'           => $ad->category ? ['id' => $ad->category->id, 'name_ar' => $ad->category->name_ar] : null,
            'city'               => $ad->city ? ['id' => $ad->city->id, 'name_ar' => $ad->city->name_ar] : null,
            'user'               => $ad->user ? [
                'id'     => $ad->user->id,
                'name'   => $ad->user->name,
                'phone'  => $ad->user->phone,
                'email'  => $ad->user->email,
                'avatar' => $ad->user->avatar,
            ] : null,
        ];
    }
}
