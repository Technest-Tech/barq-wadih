<?php

namespace App\Observers;

use App\Enums\AdStatus;
use App\Jobs\SendFollowNotificationJob;
use App\Models\Ad;

class AdObserver
{
    /**
     * When an ad is created with active status, increment counters.
     */
    public function created(Ad $ad): void
    {
        if ($ad->status === AdStatus::Active) {
            $this->incrementCounters($ad);
            $this->dispatchFollowNotifications($ad);
        }
    }

    /**
     * When an ad's status changes, update counters accordingly.
     */
    public function updated(Ad $ad): void
    {
        if (! $ad->wasChanged('status')) {
            return;
        }

        $oldStatus = AdStatus::tryFrom((string) $ad->getRawOriginal('status'));
        $newStatus = $ad->status;

        $wasActive = $oldStatus === AdStatus::Active;
        $isActive = $newStatus === AdStatus::Active;

        if ($wasActive && ! $isActive) {
            $this->decrementCounters($ad);
        } elseif (! $wasActive && $isActive) {
            $this->incrementCounters($ad);
            $this->dispatchFollowNotifications($ad);
        }
    }

    /**
     * When an ad is soft-deleted, decrement if it was active.
     */
    public function deleted(Ad $ad): void
    {
        if ($ad->status === AdStatus::Active) {
            $this->decrementCounters($ad);
        }
    }

    /**
     * When a soft-deleted ad is restored and active, increment.
     */
    public function restored(Ad $ad): void
    {
        if ($ad->status === AdStatus::Active) {
            $this->incrementCounters($ad);
        }
    }

    private function incrementCounters(Ad $ad): void
    {
        if ($ad->category_id) {
            Ad::withoutEvents(function () use ($ad) {
                $ad->category?->increment('ads_count');
            });
        }
        if ($ad->city_id) {
            Ad::withoutEvents(function () use ($ad) {
                $ad->city?->increment('ads_count');
            });
        }
    }

    private function decrementCounters(Ad $ad): void
    {
        if ($ad->category_id) {
            Ad::withoutEvents(function () use ($ad) {
                $ad->category?->decrement('ads_count');
            });
        }
        if ($ad->city_id) {
            Ad::withoutEvents(function () use ($ad) {
                $ad->city?->decrement('ads_count');
            });
        }
    }

    // ── Sprint 10: Notify followers ──────────────────────────────────────────

    private function dispatchFollowNotifications(Ad $ad): void
    {
        SendFollowNotificationJob::dispatch($ad->id)
            ->onQueue('notifications');
    }
}
