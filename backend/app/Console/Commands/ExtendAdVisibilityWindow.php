<?php

namespace App\Console\Commands;

use App\Enums\AdStatus;
use App\Models\Ad;
use Illuminate\Console\Command;

/**
 * Ads used to be published with a 30-day window. The window is 3 months now
 * (see Ad::VISIBLE_MONTHS), but only for ads created since that change —
 * everything published before it still carries the old expiry and would drop
 * out of the feed a month after publication.
 *
 * This is a one-off backfill: run it once after deploying the longer window.
 * It is safe to run again, since it only ever moves an expiry forward.
 */
class ExtendAdVisibilityWindow extends Command
{
    protected $signature = 'ads:extend-visibility {--dry-run : List what would change without writing}';

    protected $description = 'Give ads published under the old 30-day window the full 3-month visibility';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');

        // Only ads still in the feed. An already-hidden ad belongs to its
        // owner's "تجديد" button, not to a bulk update.
        $ads = Ad::query()
            ->where('status', AdStatus::Active->value)
            ->get(['id', 'created_at', 'expires_at']);

        $updated = 0;

        foreach ($ads as $ad) {
            // Measured from creation, never from published_at: "تحديث" resets
            // published_at to now, so anchoring there would hand a fresh 3
            // months to every ad its owner bumps, every time this is run.
            $fullWindow = $ad->created_at->copy()->addMonths(Ad::VISIBLE_MONTHS);

            // Already on the long window (or renewed past it) — leave it alone.
            if (! $ad->expires_at->lessThan($fullWindow)) {
                continue;
            }

            $this->line(sprintf(
                'Ad #%d: %s → %s',
                $ad->id,
                $ad->expires_at->toDateString(),
                $fullWindow->toDateString(),
            ));

            if (! $dryRun) {
                // Straight to the query builder: this is a data fix, and it
                // should not touch updated_at, the search index or observers.
                Ad::withoutEvents(
                    fn () => Ad::whereKey($ad->id)->update(['expires_at' => $fullWindow])
                );
            }

            $updated++;
        }

        $this->info($dryRun
            ? "{$updated} ad(s) would be extended to ".Ad::VISIBLE_MONTHS.' months.'
            : "Extended {$updated} ad(s) to ".Ad::VISIBLE_MONTHS.' months.');

        return self::SUCCESS;
    }
}
