<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Jeddah was seeded twice: once under Riyadh (slug=jeddah) by mistake,
 * and correctly under Makkah (slug=jeddah-makkah).
 *
 * This migration:
 *  1. Reassigns the canonical slug `jeddah` to Makkah region.
 *  2. Merges districts from `jeddah-makkah` into `jeddah`.
 *  3. Moves ads that referenced `jeddah-makkah` to `jeddah`.
 *  4. Deletes the now-redundant `jeddah-makkah` row.
 */
return new class extends Migration
{
    public function up(): void
    {
        $makkahRegion = DB::table('regions')->where('slug', 'makkah')->first();
        if (! $makkahRegion) {
            return;
        }

        $jeddah        = DB::table('cities')->where('slug', 'jeddah')->first();
        $jeddahMakkah  = DB::table('cities')->where('slug', 'jeddah-makkah')->first();

        if (! $jeddah && ! $jeddahMakkah) {
            return;
        }

        // Case: only the wrong jeddah (riyadh) exists — just fix its region.
        if ($jeddah && ! $jeddahMakkah) {
            DB::table('cities')
                ->where('id', $jeddah->id)
                ->update(['region_id' => $makkahRegion->id]);

            DB::table('districts')
                ->where('city_id', $jeddah->id)
                ->update(['region_id' => $makkahRegion->id]);

            return;
        }

        // Case: both exist — merge jeddah-makkah into jeddah, then delete jeddah-makkah.
        if ($jeddah && $jeddahMakkah) {
            // 1. Fix canonical city's region.
            DB::table('cities')
                ->where('id', $jeddah->id)
                ->update(['region_id' => $makkahRegion->id]);

            // 2. Reassign districts that belong to jeddah-makkah → jeddah.
            DB::table('districts')
                ->where('city_id', $jeddahMakkah->id)
                ->update([
                    'city_id'   => $jeddah->id,
                    'region_id' => $makkahRegion->id,
                ]);

            // Fix region on any existing jeddah districts too.
            DB::table('districts')
                ->where('city_id', $jeddah->id)
                ->update(['region_id' => $makkahRegion->id]);

            // 3. Move ads that point to jeddah-makkah → jeddah.
            DB::table('ads')
                ->where('city_id', $jeddahMakkah->id)
                ->update(['city_id' => $jeddah->id]);

            // 4. Remove the duplicate city.
            DB::table('cities')->where('id', $jeddahMakkah->id)->delete();

            return;
        }

        // Case: only jeddah-makkah exists — rename its slug to jeddah and fix region.
        if (! $jeddah && $jeddahMakkah) {
            DB::table('cities')
                ->where('id', $jeddahMakkah->id)
                ->update([
                    'slug'      => 'jeddah',
                    'region_id' => $makkahRegion->id,
                ]);

            DB::table('districts')
                ->where('city_id', $jeddahMakkah->id)
                ->update(['region_id' => $makkahRegion->id]);
        }
    }

    public function down(): void
    {
        // Reverting a data-fix migration is not safe; no-op.
    }
};
