<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Switch every category to the published fee model:
 *   • Publishing is FREE everywhere  → publish fees zeroed.
 *   • Commission is a flat amount due AFTER the sale (VAT-inclusive):
 *       - Cars & Vehicles tree : 99 ر.س
 *       - All other paid sections: 10 ر.س
 *       - Free sections (e.g. Jobs): 0
 *   • commission_trigger = after_sale for all.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Free publishing for all categories.
        DB::table('categories')->update([
            'publish_fee_individual' => 0,
            'publish_fee_dealer'     => 0,
            'commission_trigger'     => 'after_sale',
        ]);

        // Identify the cars/vehicles tree (top-level "cars" + its children).
        $carsParentId = DB::table('categories')->where('slug', 'cars')->value('id');
        $carsIds = [];
        if ($carsParentId) {
            $carsIds[] = (int) $carsParentId;
            $childIds = DB::table('categories')->where('parent_id', $carsParentId)->pluck('id')->all();
            $carsIds = array_merge($carsIds, array_map('intval', $childIds));
        }

        // Cars tree → 99 ر.س flat commission.
        if (! empty($carsIds)) {
            DB::table('categories')->whereIn('id', $carsIds)->update([
                'deferred_commission_individual' => 99,
                'deferred_commission_dealer'     => 99,
                'is_free'                        => false,
            ]);
        }

        // All other paid categories → 10 ر.س flat commission.
        DB::table('categories')
            ->when(! empty($carsIds), fn ($q) => $q->whereNotIn('id', $carsIds))
            ->where('is_free', false)
            ->update([
                'deferred_commission_individual' => 10,
                'deferred_commission_dealer'     => 10,
            ]);

        // Free categories owe nothing.
        DB::table('categories')->where('is_free', true)->update([
            'deferred_commission_individual' => 0,
            'deferred_commission_dealer'     => 0,
        ]);
    }

    public function down(): void
    {
        // Non-destructive: previous per-category fee values are not restored.
    }
};
