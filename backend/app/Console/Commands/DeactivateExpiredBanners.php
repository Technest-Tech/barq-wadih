<?php

namespace App\Console\Commands;

use App\Models\Banner;
use Illuminate\Console\Command;

class DeactivateExpiredBanners extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'banners:deactivate-expired';

    /**
     * The console command description.
     */
    protected $description = 'Deactivate banners whose end date has passed';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $count = Banner::where('is_active', true)
            ->where('ends_at', '<', now())
            ->update(['is_active' => false]);

        $this->info("Deactivated {$count} expired banner(s).");

        return self::SUCCESS;
    }
}
