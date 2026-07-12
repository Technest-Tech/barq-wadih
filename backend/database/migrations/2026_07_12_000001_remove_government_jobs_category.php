<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $category = DB::table('categories')->where('slug', 'government-jobs')->first();

        if (! $category) {
            return;
        }

        $ids = array_merge(
            [$category->id],
            DB::table('categories')->where('parent_id', $category->id)->pluck('id')->toArray(),
        );

        $adIds = DB::table('ads')->whereIn('category_id', $ids)->pluck('id')->toArray();

        if (! empty($adIds)) {
            DB::table('ad_field_values')->whereIn('ad_id', $adIds)->delete();
            DB::table('ad_images')->whereIn('ad_id', $adIds)->delete();
            DB::table('favorites')->whereIn('ad_id', $adIds)->delete();
            DB::table('ad_boosts')->whereIn('ad_id', $adIds)->delete();
            DB::table('reports')->whereIn('ad_id', $adIds)->delete();
            DB::table('ratings')->whereIn('ad_id', $adIds)->delete();
            DB::table('commission_payments')->whereIn('ad_id', $adIds)->delete();
            DB::table('ads')->whereIn('id', $adIds)->delete();
        }

        DB::table('category_fields')->whereIn('category_id', $ids)->delete();
        DB::table('category_follows')->whereIn('category_id', $ids)->delete();

        DB::table('banners')->where('link_url', 'LIKE', '%government-jobs%')->delete();

        DB::table('categories')->whereIn('id', $ids)->delete();
    }

    public function down(): void
    {
        // Not reversible — the category is intentionally retired.
    }
};
