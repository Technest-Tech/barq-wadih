<?php

namespace App\Services;

use App\Enums\AdStatus;
use App\Enums\BoostType;
use App\Models\Ad;
use App\Models\AdBoost;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class BoostService
{
    // ── Premium Boost ────────────────────────────────────────────────────────

    /**
     * Apply a premium boost to an ad.
     * Sets is_boosted = true and boosted_until = now + duration.
     */
    public function boostPremium(Ad $ad, User $user): AdBoost
    {
        [$canBoost, $reason] = $this->canBoost($ad, $user);

        if (! $canBoost) {
            abort(422, $reason);
        }

        $durationHours = (int) SystemSetting::get('boost_premium_duration_hours', 72);
        $expiresAt = now()->addHours($durationHours);

        return DB::transaction(function () use ($ad, $user, $expiresAt) {
            $ad->update([
                'is_boosted'    => true,
                'boosted_until' => $expiresAt,
            ]);

            return AdBoost::create([
                'ad_id'      => $ad->id,
                'user_id'    => $user->id,
                'boosted_at' => now(),
                'expires_at' => $expiresAt,
                'boost_type' => BoostType::Premium->value,
            ]);
        });
    }

    // ── Refresh ──────────────────────────────────────────────────────────────

    /**
     * Refresh an ad — reset published_at to now, moving it to the top
     * of the chronological feed (below boosted ads).
     */
    public function refresh(Ad $ad, User $user): AdBoost
    {
        [$canRefresh, $reason] = $this->canRefresh($ad, $user);

        if (! $canRefresh) {
            abort(422, $reason);
        }

        return DB::transaction(function () use ($ad, $user) {
            $ad->update([
                'published_at' => now(),
            ]);

            return AdBoost::create([
                'ad_id'      => $ad->id,
                'user_id'    => $user->id,
                'boosted_at' => now(),
                'expires_at' => null,
                'boost_type' => BoostType::Refresh->value,
            ]);
        });
    }

    // ── Can-checks ───────────────────────────────────────────────────────────

    /**
     * Check if an ad can be boosted (premium).
     *
     * @return array{0: bool, 1: string}  [canBoost, reason]
     */
    public function canBoost(Ad $ad, User $user): array
    {
        if ($ad->user_id !== $user->id) {
            return [false, 'لا يمكنك ترقية إعلان لا يخصك.'];
        }

        if ($ad->status !== AdStatus::Active) {
            return [false, 'يمكن ترقية الإعلانات النشطة فقط.'];
        }

        // Already boosted with time remaining
        if ($ad->is_boosted && $ad->boosted_until?->isFuture()) {
            return [false, 'هذا الإعلان مميز بالفعل حتى ' . $ad->boosted_until->format('Y-m-d H:i')];
        }

        // Check user's max active boosts
        $maxActive = (int) SystemSetting::get('boost_max_active_per_user', 5);
        $currentActive = Ad::where('user_id', $user->id)
            ->where('is_boosted', true)
            ->where('boosted_until', '>', now())
            ->count();

        if ($currentActive >= $maxActive) {
            return [false, "لقد وصلت للحد الأقصى من الإعلانات المميزة ({$maxActive})."];
        }

        return [true, ''];
    }

    /**
     * Check if an ad can be refreshed.
     *
     * @return array{0: bool, 1: string, 2: ?string}  [canRefresh, reason, nextRefreshAt ISO]
     */
    public function canRefresh(Ad $ad, User $user): array
    {
        if ($ad->user_id !== $user->id) {
            return [false, 'لا يمكنك تحديث إعلان لا يخصك.', null];
        }

        if ($ad->status !== AdStatus::Active) {
            return [false, 'يمكن تحديث الإعلانات النشطة فقط.', null];
        }

        // Cooldown check — last refresh for this specific ad
        $cooldownHours = (int) SystemSetting::get('boost_refresh_cooldown_hours', 24);
        $lastRefresh = AdBoost::where('ad_id', $ad->id)
            ->where('boost_type', BoostType::Refresh->value)
            ->latest('boosted_at')
            ->first();

        if ($lastRefresh && $lastRefresh->boosted_at->diffInHours(now()) < $cooldownHours) {
            $nextRefreshAt = $lastRefresh->boosted_at->addHours($cooldownHours);
            return [
                false,
                'يجب الانتظار قبل تحديث الإعلان مرة أخرى.',
                $nextRefreshAt->toISOString(),
            ];
        }

        return [true, '', null];
    }

    // ── Config ───────────────────────────────────────────────────────────────

    /**
     * Get boost pricing and rules config for the frontend.
     */
    public function getConfig(): array
    {
        $price = (float) SystemSetting::get('boost_premium_price', 0);

        return [
            'premium_duration_hours' => (int) SystemSetting::get('boost_premium_duration_hours', 72),
            'premium_price'          => $price,
            'refresh_cooldown_hours' => (int) SystemSetting::get('boost_refresh_cooldown_hours', 24),
            'max_active_boosts'      => (int) SystemSetting::get('boost_max_active_per_user', 5),
            'is_free_period'         => $price <= 0,
        ];
    }
}
