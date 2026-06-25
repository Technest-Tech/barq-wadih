<?php

namespace App\Console\Commands;

use App\Models\Category;
use Illuminate\Console\Command;

/**
 * Point the main (top-level) categories at the self-hosted gradient-tile SVG
 * icons in public/category-icons. Both the mobile app and the website render
 * the category `image` field, so updating it changes the icons everywhere at
 * once. Idempotent — safe to re-run after a deploy or fresh seed.
 */
class SetCategoryIcons extends Command
{
    protected $signature = 'categories:set-icons';

    protected $description = 'Point main categories at the self-hosted gradient-tile SVG icons';

    /** Top-level category slugs that have a matching public/category-icons/<slug>.svg. */
    private const SLUGS = [
        'cars', 'electronics', 'furniture', 'jobs', 'services', 'fashion',
        'sports-leisure', 'books-magazines', 'toys-kids', 'animals',
        'personal-items', 'hunting-trips', 'food-beverages', 'other',
    ];

    public function handle(): int
    {
        $base = rtrim((string) config('app.url'), '/').'/category-icons/';
        $updated = 0;

        foreach (self::SLUGS as $slug) {
            $url = $base.$slug.'.svg';

            // Match only top-level categories (parent_id is null) to avoid an
            // accidental clash with a same-named subcategory.
            $rows = Category::where('slug', $slug)
                ->whereNull('parent_id')
                ->update(['image' => $url]);

            if ($rows > 0) {
                $updated++;
                $this->line("  ✓ {$slug} → {$url}");
            } else {
                $this->warn("  - {$slug} not found (skipped)");
            }
        }

        $this->info("Updated {$updated}/".count(self::SLUGS).' category icons.');

        return self::SUCCESS;
    }
}
