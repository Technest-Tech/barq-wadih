<?php

namespace App\Services;

use App\Enums\CampaignStatus;
use App\Enums\CampaignTargetType;
use App\Models\NotificationCampaign;
use App\Models\User;

/**
 * Single delivery path for admin broadcast / direct messages.
 *
 * The controller and the `campaigns:send-scheduled` command both funnel
 * through here so recipient resolution and delivery can never drift apart
 * again — and, unlike the previous inline code, this actually dispatches FCM
 * instead of only writing in-app rows.
 */
class CampaignSender
{
    /** Users per delivery batch — keeps the device lookup's IN() clause sane. */
    private const BATCH = 500;

    public function __construct(private readonly PushService $push) {}

    /**
     * Resolve the campaign's audience.
     *
     * @return int[]
     */
    public function resolveRecipients(NotificationCampaign $campaign): array
    {
        return match ($campaign->target_type) {
            CampaignTargetType::All => User::where('is_active', true)->pluck('id')->all(),

            CampaignTargetType::City => User::where('is_active', true)
                ->whereHas('ads', fn ($q) => $q->where('city_id', $campaign->target_city_id))
                ->pluck('id')->all(),

            CampaignTargetType::Category => User::where('is_active', true)
                ->whereHas('categoryFollows', fn ($q) => $q->where('category_id', $campaign->target_category_id))
                ->pluck('id')->all(),

            // Re-check is_active: the ids were picked in the composer and the
            // account may have been suspended between then and the send.
            CampaignTargetType::SpecificUsers => User::where('is_active', true)
                ->whereIn('id', $campaign->target_user_ids ?? [])
                ->pluck('id')->all(),
        };
    }

    /**
     * How many users the campaign would reach right now, without sending.
     */
    public function estimateAudience(NotificationCampaign $campaign): int
    {
        return count($this->resolveRecipients($campaign));
    }

    /**
     * Deliver the campaign: in-app notification rows + FCM push.
     *
     * Returns the number of recipients. Marks the campaign Sent on success;
     * the caller is responsible for marking it Failed if this throws.
     */
    public function deliver(NotificationCampaign $campaign): int
    {
        $recipientIds = $this->resolveRecipients($campaign);
        $total        = count($recipientIds);
        $reached      = 0;

        // `type` is what the web and mobile clients route on, so default it to
        // 'campaign' (no deep link — the message is the whole point) while
        // letting a campaign that carries its own data override it.
        $data = array_merge(
            ['type' => 'campaign'],
            $campaign->data ?? [],
            ['campaign_id' => $campaign->id],
        );

        foreach (array_chunk($recipientIds, self::BATCH) as $chunk) {
            $reached += $this->push->sendToUsers(
                $chunk,
                'campaign',
                $campaign->title_ar,
                $campaign->body_ar,
                $data,
                $campaign->title_en,
                $campaign->body_en,
            );
        }

        $campaign->update([
            'status'           => CampaignStatus::Sent->value,
            'sent_at'          => now(),
            'recipients_count' => $total,
            // Users we could actually push to. The rest still get the in-app
            // bell notification, they just have no registered device.
            'delivered_count'  => $reached,
        ]);

        return $total;
    }
}
