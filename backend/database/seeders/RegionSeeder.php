<?php

namespace Database\Seeders;

use App\Models\Region;
use Illuminate\Database\Seeder;

class RegionSeeder extends Seeder
{
    public function run(): void
    {
        $regions = [
            ['name_ar' => 'منطقة الرياض',          'name_en' => 'Riyadh Region',             'slug' => 'riyadh',             'sort_order' => 1],
            ['name_ar' => 'منطقة مكة المكرمة',     'name_en' => 'Makkah Region',             'slug' => 'makkah',             'sort_order' => 2],
            ['name_ar' => 'منطقة المدينة المنورة', 'name_en' => 'Madinah Region',            'slug' => 'madinah',            'sort_order' => 3],
            ['name_ar' => 'منطقة القصيم',          'name_en' => 'Qassim Region',             'slug' => 'qassim',             'sort_order' => 4],
            ['name_ar' => 'المنطقة الشرقية',       'name_en' => 'Eastern Province',          'slug' => 'eastern-province',   'sort_order' => 5],
            ['name_ar' => 'منطقة عسير',            'name_en' => 'Aseer Region',              'slug' => 'aseer',              'sort_order' => 6],
            ['name_ar' => 'منطقة تبوك',            'name_en' => 'Tabuk Region',              'slug' => 'tabuk',              'sort_order' => 7],
            ['name_ar' => 'منطقة حائل',            'name_en' => 'Hail Region',               'slug' => 'hail',               'sort_order' => 8],
            ['name_ar' => 'منطقة الحدود الشمالية', 'name_en' => 'Northern Borders Region',   'slug' => 'northern-borders',   'sort_order' => 9],
            ['name_ar' => 'منطقة جازان',           'name_en' => 'Jizan Region',              'slug' => 'jizan',              'sort_order' => 10],
            ['name_ar' => 'منطقة نجران',           'name_en' => 'Najran Region',             'slug' => 'najran',             'sort_order' => 11],
            ['name_ar' => 'منطقة الباحة',          'name_en' => 'Al-Bahah Region',           'slug' => 'al-bahah',           'sort_order' => 12],
            ['name_ar' => 'منطقة الجوف',           'name_en' => 'Al-Jouf Region',            'slug' => 'al-jouf',            'sort_order' => 13],
        ];

        foreach ($regions as $region) {
            Region::firstOrCreate(
                ['slug' => $region['slug']],
                array_merge($region, ['is_active' => true])
            );
        }
    }
}
