<?php

namespace App\Jobs;

use App\Enums\CampaignStatus;
use App\Models\NotificationCampaign;
use App\Services\CampaignSender;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Delivers an admin campaign off the request cycle.
 *
 * A broadcast to every user writes one notification row per recipient and
 * multicasts FCM in batches — far too slow to do inside the admin's HTTP
 * request once the user base grows.
 */
class SendCampaignJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 1;

    public int $timeout = 600;

    public function __construct(
        public readonly int $campaignId,
    ) {}

    public function handle(CampaignSender $sender): void
    {
        $campaign = NotificationCampaign::find($this->campaignId);

        if (! $campaign) {
            return;
        }

        // A double-click on "send" can enqueue this twice; the first run wins.
        if ($campaign->status === CampaignStatus::Sent) {
            return;
        }

        $sender->deliver($campaign);
    }

    public function failed(\Throwable $e): void
    {
        Log::error("Campaign #{$this->campaignId} failed to send: {$e->getMessage()}");

        NotificationCampaign::where('id', $this->campaignId)
            ->update(['status' => CampaignStatus::Failed->value]);
    }
}
