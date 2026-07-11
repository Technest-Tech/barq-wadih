<?php

namespace App\Console\Commands;

use App\Models\Category;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

/**
 * Give every category that already has subcategories an «أخرى» catch-all child,
 * so a seller whose item isn't in the list (any furniture that isn't a bedroom,
 * a kitchen, …) still has somewhere to post it.
 *
 * Works against the LIVE tree rather than the seeder, because production's
 * taxonomy is curated and does not match CategorySeeder. Idempotent — a parent
 * that already has an «أخرى» child gets it normalised (name, icon, last in the
 * sort order) instead of a duplicate. Categories with no children are skipped:
 * they're posted to directly, so a lone «أخرى» child would only add a pointless
 * extra step.
 */
class AddOtherSubcategories extends Command
{
    protected $signature = 'categories:add-other {--dry-run : List what would change without writing}';

    protected $description = 'Ensure every category with subcategories has an «أخرى» catch-all child';

    public function handle(): int
    {
        $dry = (bool) $this->option('dry-run');
        $created = 0;
        $normalised = 0;

        // Every category that has at least one child — main categories and
        // mid-level ones alike (e.g. حيوانات → طيور → حمام/دجاج).
        $parents = Category::whereIn('id', Category::whereNotNull('parent_id')->distinct()->pluck('parent_id'))
            ->orderBy('sort_order')
            ->get();

        foreach ($parents as $parent) {
            $existing = Category::where('parent_id', $parent->id)
                ->where(fn ($q) => $q->where('name_ar', 'أخرى')->orWhere('slug', 'like', 'other-%'))
                ->first();

            $slug = $existing->slug ?? 'other-'.$parent->slug;

            $attrs = [
                'parent_id' => $parent->id,
                'name_ar' => 'أخرى',
                'name_en' => 'Other',
                'slug' => $slug,
                'icon' => '📦',
                'sort_order' => 99,
                'is_active' => true,
                // Inherit the parent's money rules so posting under «أخرى» costs
                // exactly what posting under any of its siblings costs.
                'is_free' => $parent->is_free,
                'commission_rate' => $parent->commission_rate,
                'commission_trigger' => $parent->commission_trigger ?? 'after_sale',
                'publish_fee_individual' => $parent->publish_fee_individual,
                'publish_fee_dealer' => $parent->publish_fee_dealer,
                'fee_deductible_from_commission' => $parent->fee_deductible_from_commission,
                'deferred_commission_individual' => $parent->deferred_commission_individual,
                'deferred_commission_dealer' => $parent->deferred_commission_dealer,
            ];

            if ($dry) {
                $this->line(sprintf(
                    '%s %s → %s',
                    $existing ? '[normalise]' : '[create]   ',
                    $parent->slug,
                    $slug,
                ));
                $existing ? $normalised++ : $created++;

                continue;
            }

            Category::updateOrCreate(['slug' => $slug], $attrs);
            $existing ? $normalised++ : $created++;
        }

        if (! $dry) {
            // The public tree is cached for an hour — drop it so the new «أخرى»
            // entries show up on the site and in the app immediately.
            Cache::forget('categories:tree');
        }

        $this->info(sprintf(
            '%s: %d created, %d normalised across %d parent categories.',
            $dry ? 'Dry run' : 'Done',
            $created,
            $normalised,
            $parents->count(),
        ));

        return self::SUCCESS;
    }
}
