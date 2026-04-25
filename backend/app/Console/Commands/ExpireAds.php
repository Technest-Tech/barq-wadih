<?php

namespace App\Console\Commands;

use App\Enums\AdStatus;
use App\Enums\ModerationStatus;
use App\Models\Ad;
use Illuminate\Console\Command;

class ExpireAds extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'ads:expire';

    /**
     * The console command description.
     */
    protected $description = 'Mark all ads past their expiry date as expired';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $count = Ad::where('status', AdStatus::Active->value)
            ->where('moderation_status', ModerationStatus::Approved->value)
            ->where('expires_at', '<', now())
            ->update(['status' => AdStatus::Expired->value]);

        $this->info("Expired {$count} ad(s).");

        return self::SUCCESS;
    }
}
