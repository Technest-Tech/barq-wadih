<?php

namespace App\Policies;

use App\Enums\AdStatus;
use App\Models\Ad;
use App\Models\User;

class AdPolicy
{
    /**
     * Owner can update an ad that is active or pending_review.
     */
    public function update(User $user, Ad $ad): bool
    {
        return $user->id === $ad->user_id
            && in_array($ad->status, [AdStatus::Active, AdStatus::PendingReview], true);
    }

    /**
     * Owner can delete any of their own ads (except already deleted).
     */
    public function delete(User $user, Ad $ad): bool
    {
        return $user->id === $ad->user_id
            && $ad->status !== AdStatus::Deleted;
    }

    /**
     * Owner can mark an active ad as sold.
     */
    public function markSold(User $user, Ad $ad): bool
    {
        return $user->id === $ad->user_id
            && $ad->status === AdStatus::Active;
    }

    /**
     * Owner can boost or refresh an active ad.
     */
    public function boost(User $user, Ad $ad): bool
    {
        return $user->id === $ad->user_id
            && $ad->status === AdStatus::Active;
    }
}
