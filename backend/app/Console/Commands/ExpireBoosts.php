<?php

namespace App\Console\Commands;

use App\Models\Ad;
use Illuminate\Console\Command;

class ExpireBoosts extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'boosts:expire';

    /**
     * The console command description.
     */
    protected $description = 'Clear expired premium boosts on ads';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $count = Ad::where('is_boosted', true)
            ->where('boosted_until', '<=', now())
            ->update([
                'is_boosted'    => false,
                'boosted_until' => null,
            ]);

        $this->info("Cleared {$count} expired boost(s).");

        return self::SUCCESS;
    }
}
