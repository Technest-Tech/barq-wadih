<?php

namespace Database\Seeders;

use App\Models\Ad;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DevDemoSeeder extends Seeder
{
    public function run(): void
    {
        // Guard — must not run in production
        if (app()->isProduction()) {
            $this->command->warn('DevDemoSeeder skipped in production!');
            return;
        }

        $this->command->info('Seeding demo data...');

        // ── Admin user ────────────────────────────────────────────────────────
        User::firstOrCreate(
            ['email' => 'admin@barqwadih.sa'],
            [
                'name'     => 'مشرف النظام',
                'password' => Hash::make('password'),
                'role'     => 'super_admin',
                'is_active'=> true,
                'is_verified' => true,
                'phone'    => '+966500000001',
                'locale'   => 'ar',
            ]
        );

        // ── Demo regular user ─────────────────────────────────────────────────
        User::firstOrCreate(
            ['email' => 'user@barqwadih.sa'],
            [
                'name'     => 'أحمد التجريبي',
                'password' => Hash::make('password'),
                'role'     => 'user',
                'is_active'=> true,
                'phone'    => '+966500000002',
                'locale'   => 'ar',
            ]
        );

        $this->command->info('Demo users created: admin@barqwadih.sa / user@barqwadih.sa (password: password)');
    }
}
