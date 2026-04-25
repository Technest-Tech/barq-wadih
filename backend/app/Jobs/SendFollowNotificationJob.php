<?php

namespace App\Jobs;

use App\Models\Ad;
use App\Models\CategoryFollow;
use App\Services\PushService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendFollowNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(
        public readonly int $adId,
    ) {}

    public function handle(PushService $pushService): void
    {
        $ad = Ad::with('category')->find($this->adId);

        if (!$ad || $ad->status->value !== 'active') {
            return;
        }

        // Find followers of this category, optionally filtered by city
        $followers = CategoryFollow::where('category_id', $ad->category_id)
            ->where(function ($q) use ($ad) {
                $q->whereNull('city_id')
                  ->orWhere('city_id', $ad->city_id);
            })
            ->where('user_id', '!=', $ad->user_id) // exclude the ad owner
            ->pluck('user_id')
            ->unique()
            ->values()
            ->toArray();

        if (empty($followers)) {
            return;
        }

        $categoryName = $ad->category?->name_ar ?? 'تصنيف';

        $pushService->sendToUsers(
            $followers,
            'new_ad_followed',
            "إعلان جديد في {$categoryName}",
            mb_substr($ad->title, 0, 100),
            [
                'type'        => 'new_ad',
                'ad_id'       => $ad->id,
                'category_id' => $ad->category_id,
            ],
        );
    }
}
