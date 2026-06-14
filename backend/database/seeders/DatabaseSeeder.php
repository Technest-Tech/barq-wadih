<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ── Production seeders (safe for all environments) ───────────────────
        $this->call([
            RegionSeeder::class,
            CitySeeder::class,
            DistrictSeeder::class,
            CategorySeeder::class,
            CategoryFieldSeeder::class,
            SystemSettingSeeder::class,
            StaticPagesSeeder::class,
        ]);

        // ── Dev/Staging only — demo data ─────────────────────────────────────
        if (app()->environment(['local', 'staging'])) {
            $this->call([
                DevDemoSeeder::class,
                SellersAndRatingsSeeder::class,
            ]);
        }
    }
}
