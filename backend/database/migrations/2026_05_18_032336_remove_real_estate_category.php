<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $parent = DB::table('categories')->where('slug', 'real-estate')->first();

        if (! $parent) {
            return;
        }

        $childIds = DB::table('categories')
            ->where('parent_id', $parent->id)
            ->pluck('id')
            ->toArray();

        $allIds = array_merge([$parent->id], $childIds);

        $adIds = DB::table('ads')->whereIn('category_id', $allIds)->pluck('id')->toArray();

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

        DB::table('category_fields')->whereIn('category_id', $allIds)->delete();
        DB::table('category_follows')->whereIn('category_id', $allIds)->delete();

        DB::table('banners')
            ->where('link_url', 'LIKE', '%real-estate%')
            ->delete();

        DB::table('categories')->whereIn('id', $childIds)->delete();
        DB::table('categories')->where('id', $parent->id)->delete();
    }

    public function down(): void
    {
        // Not reversible — re-run CategorySeeder to restore
    }
};
