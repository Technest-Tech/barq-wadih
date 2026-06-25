<?php

namespace App\Jobs;

use App\Models\Ad;
use App\Services\PushService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Notifies the seller when an admin reviews their bank-transfer commission
 * receipt — approved or rejected. Creates an in-app notification (shown on web
 * + mobile) and pushes FCM. A rejection carries the reason so the seller knows
 * why and can upload a corrected receipt.
 */
class SendCommissionReviewNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(
        public readonly int $adId,
        public readonly bool $approved,
        public readonly ?string $reason = null,
    ) {}

    public function handle(PushService $pushService): void
    {
        $ad = Ad::find($this->adId);

        if (! $ad || ! $ad->user_id) {
            return;
        }

        $amount = (float) ($ad->payment_amount ?? $ad->commission_amount ?? 0);

        if ($this->approved) {
            $pushService->sendToUser(
                $ad->user_id,
                'commission_approved',
                'تم اعتماد تحويل العمولة ✅',
                "تم تأكيد سداد عمولة البيع لإعلانك: {$ad->title}",
                [
                    'type'   => 'commission_approved',
                    'ad_id'  => (string) $ad->id,
                    'status' => 'approved',
                ],
            );

            return;
        }

        $reason = trim((string) $this->reason);

        $pushService->sendToUser(
            $ad->user_id,
            'commission_rejected',
            'تم رفض إيصال التحويل ⚠️',
            $reason !== ''
                ? "سبب الرفض: {$reason} — يمكنك إرفاق إيصال جديد."
                : "تم رفض إيصال التحويل لإعلانك: {$ad->title} — يمكنك إرفاق إيصال جديد.",
            [
                'type'   => 'commission_rejected',
                'ad_id'  => (string) $ad->id,
                'status' => 'rejected',
                'reason' => $reason,
                'amount' => (string) $amount,
            ],
        );
    }
}
