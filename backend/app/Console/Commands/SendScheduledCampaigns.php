<?php

namespace App\Console\Commands;

use App\Enums\CampaignStatus;
use App\Models\Notification;
use App\Models\NotificationCampaign;
use App\Models\User;
use Illuminate\Console\Command;

class SendScheduledCampaigns extends Command
{
    protected $signature = 'campaigns:send-scheduled';
    protected $description = 'Send notification campaigns that are scheduled and due.';

    public function handle(): int
    {
        $campaigns = NotificationCampaign::where('status', CampaignStatus::Scheduled->value)
            ->where('scheduled_at', '<=', now())
            ->get();

        if ($campaigns->isEmpty()) {
            $this->info('No scheduled campaigns due.');
            return 0;
        }

        foreach ($campaigns as $campaign) {
            $this->info("Sending campaign #{$campaign->id}: {$campaign->title_ar}");

            try {
                $recipientIds = $this->resolveRecipients($campaign);
                $count        = count($recipientIds);

                $now = now();
                $notifications = [];
                foreach ($recipientIds as $userId) {
                    $notifications[] = [
                        'user_id'    => $userId,
                        'type'       => 'campaign',
                        'title_ar'   => $campaign->title_ar,
                        'title_en'   => $campaign->title_en,
                        'body_ar'    => $campaign->body_ar,
                        'body_en'    => $campaign->body_en,
                        'data'       => json_encode(['campaign_id' => $campaign->id]),
                        'channel'    => 'push',
                        'is_read'    => false,
                        'sent_at'    => $now,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }

                foreach (array_chunk($notifications, 500) as $chunk) {
                    Notification::insert($chunk);
                }

                $campaign->update([
                    'status'           => CampaignStatus::Sent->value,
                    'sent_at'          => $now,
                    'recipients_count' => $count,
                    'delivered_count'  => $count,
                ]);

                $this->info("  → Sent to {$count} recipients.");
            } catch (\Throwable $e) {
                $campaign->update(['status' => CampaignStatus::Failed->value]);
                $this->error("  → Failed: {$e->getMessage()}");
            }
        }

        return 0;
    }

    private function resolveRecipients(NotificationCampaign $campaign): array
    {
        return match ($campaign->target_type) {
            \App\Enums\CampaignTargetType::All => User::where('is_active', true)->pluck('id')->toArray(),
            \App\Enums\CampaignTargetType::City => User::where('is_active', true)
                ->whereHas('ads', fn ($q) => $q->where('city_id', $campaign->target_city_id))
                ->pluck('id')->toArray(),
            \App\Enums\CampaignTargetType::Category => User::where('is_active', true)
                ->whereHas('categoryFollows', fn ($q) => $q->where('category_id', $campaign->target_category_id))
                ->pluck('id')->toArray(),
            \App\Enums\CampaignTargetType::SpecificUsers => $campaign->target_user_ids ?? [],
        };
    }
}
