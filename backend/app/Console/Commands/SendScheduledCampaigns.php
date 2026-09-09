<?php

namespace App\Console\Commands;

use App\Enums\CampaignStatus;
use App\Models\NotificationCampaign;
use App\Services\CampaignSender;
use Illuminate\Console\Command;

class SendScheduledCampaigns extends Command
{
    protected $signature = 'campaigns:send-scheduled';

    protected $description = 'Send notification campaigns that are scheduled and due.';

    public function handle(CampaignSender $sender): int
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
                $count = $sender->deliver($campaign);
                $this->info("  → Sent to {$count} recipients.");
            } catch (\Throwable $e) {
                $campaign->update(['status' => CampaignStatus::Failed->value]);
                $this->error("  → Failed: {$e->getMessage()}");
            }
        }

        return 0;
    }
}
