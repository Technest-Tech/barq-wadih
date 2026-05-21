<?php

namespace App\Jobs;

use App\Models\Ad;
use App\Services\PushService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendSaleFeeNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(
        public readonly int $adId,
    ) {}

    public function handle(PushService $pushService): void
    {
        $ad = Ad::find($this->adId);

        if (!$ad || !$ad->user_id) {
            return;
        }

        $price = $ad->price ? (float) $ad->price : null;

        $data = [
            'type'   => 'sale_fee',
            'ad_id'  => $ad->id,
            'price'  => $price !== null ? strval($price) : null,
        ];

        $pushService->sendToUser(
            $ad->user_id,
            'sale_fee',
            'تهانينا! أعلنت بيع إعلانك 🎉',
            $price !== null
                ? "احسب رسوم البيع لإعلان: {$ad->title}"
                : "تذكّر سداد رسوم البيع لإعلانك: {$ad->title}",
            $data,
        );
    }
}
