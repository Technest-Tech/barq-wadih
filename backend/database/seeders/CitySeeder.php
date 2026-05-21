<?php

namespace Database\Seeders;

use App\Models\City;
use App\Models\Region;
use Illuminate\Database\Seeder;

class CitySeeder extends Seeder
{
    public function run(): void
    {
        $data = [
            'riyadh' => [
                ['name_ar' => 'الرياض',          'name_en' => 'Riyadh',          'slug' => 'riyadh-city',       'latitude' => 24.7136, 'longitude' => 46.6753, 'sort_order' => 1],
                ['name_ar' => 'الخرج',            'name_en' => 'Al-Kharj',        'slug' => 'al-kharj',          'latitude' => 24.1552, 'longitude' => 47.3164, 'sort_order' => 2],
                ['name_ar' => 'المزاحمية',        'name_en' => 'Al-Muzahmiyya',   'slug' => 'al-muzahmiyya',     'latitude' => 24.5003, 'longitude' => 46.2802, 'sort_order' => 3],
                ['name_ar' => 'الدوادمي',         'name_en' => 'Al-Dawadmi',      'slug' => 'al-dawadmi',        'latitude' => 24.4991, 'longitude' => 44.3877, 'sort_order' => 4],
                ['name_ar' => 'رماح',             'name_en' => 'Rumah',           'slug' => 'rumah',             'latitude' => 25.5681, 'longitude' => 47.1769, 'sort_order' => 5],
                ['name_ar' => 'ثادق',             'name_en' => 'Thadiq',          'slug' => 'thadiq',            'latitude' => 25.9770, 'longitude' => 45.8715, 'sort_order' => 6],
                ['name_ar' => 'حوطة بني تميم',   'name_en' => 'Huta Bani Tamim', 'slug' => 'huta-bani-tamim',   'latitude' => 23.5241, 'longitude' => 46.8357, 'sort_order' => 7],
                ['name_ar' => 'الأفلاج',          'name_en' => 'Al-Aflaj',        'slug' => 'al-aflaj',          'latitude' => 22.2801, 'longitude' => 46.7246, 'sort_order' => 8],
                ['name_ar' => 'وادي الدواسر',    'name_en' => 'Wadi Al-Dawasir', 'slug' => 'wadi-al-dawasir',   'latitude' => 20.4878, 'longitude' => 44.9868, 'sort_order' => 9],
            ],
            'makkah' => [
                ['name_ar' => 'مكة المكرمة',      'name_en' => 'Makkah',          'slug' => 'makkah-city',       'latitude' => 21.3891, 'longitude' => 39.8579, 'sort_order' => 1],
                ['name_ar' => 'جدة',              'name_en' => 'Jeddah',          'slug' => 'jeddah',            'latitude' => 21.4858, 'longitude' => 39.1925, 'sort_order' => 2],
                ['name_ar' => 'الطائف',           'name_en' => 'Taif',            'slug' => 'taif',              'latitude' => 21.2703, 'longitude' => 40.4158, 'sort_order' => 3],
                ['name_ar' => 'القنفذة',          'name_en' => 'Al-Qunfudhah',    'slug' => 'al-qunfudhah',      'latitude' => 19.1282, 'longitude' => 41.0792, 'sort_order' => 4],
                ['name_ar' => 'رابغ',             'name_en' => 'Rabigh',          'slug' => 'rabigh',            'latitude' => 22.7988, 'longitude' => 38.9883, 'sort_order' => 5],
                ['name_ar' => 'الجموم',           'name_en' => 'Al-Jumum',        'slug' => 'al-jumum',          'latitude' => 21.6272, 'longitude' => 39.7144, 'sort_order' => 6],
                ['name_ar' => 'خليص',             'name_en' => 'Khulays',         'slug' => 'khulays',           'latitude' => 22.1504, 'longitude' => 39.3188, 'sort_order' => 7],
            ],
            'madinah' => [
                ['name_ar' => 'المدينة المنورة',  'name_en' => 'Madinah',         'slug' => 'madinah-city',      'latitude' => 24.5247, 'longitude' => 39.5692, 'sort_order' => 1],
                ['name_ar' => 'ينبع',             'name_en' => 'Yanbu',           'slug' => 'yanbu',             'latitude' => 24.0897, 'longitude' => 38.0618, 'sort_order' => 2],
                ['name_ar' => 'العلا',            'name_en' => 'Al-Ula',          'slug' => 'al-ula',            'latitude' => 26.6136, 'longitude' => 37.9224, 'sort_order' => 3],
                ['name_ar' => 'بدر',              'name_en' => 'Badr',            'slug' => 'badr',              'latitude' => 23.7839, 'longitude' => 38.7897, 'sort_order' => 4],
                ['name_ar' => 'المهد',            'name_en' => 'Al-Mahd',         'slug' => 'al-mahd',           'latitude' => 23.4721, 'longitude' => 40.3067, 'sort_order' => 5],
            ],
            'qassim' => [
                ['name_ar' => 'بريدة',            'name_en' => 'Buraydah',        'slug' => 'buraydah',          'latitude' => 26.3260, 'longitude' => 43.9750, 'sort_order' => 1],
                ['name_ar' => 'عنيزة',            'name_en' => 'Unayzah',         'slug' => 'unayzah',           'latitude' => 26.0840, 'longitude' => 43.9931, 'sort_order' => 2],
                ['name_ar' => 'الرس',             'name_en' => 'Ar-Rass',         'slug' => 'ar-rass',           'latitude' => 25.8636, 'longitude' => 43.4975, 'sort_order' => 3],
                ['name_ar' => 'المذنب',           'name_en' => 'Al-Midhnab',      'slug' => 'al-midhnab',        'latitude' => 25.8570, 'longitude' => 44.2350, 'sort_order' => 4],
                ['name_ar' => 'النبهانية',        'name_en' => 'Al-Nabhaniyah',   'slug' => 'al-nabhaniyah',     'latitude' => 25.6500, 'longitude' => 44.5500, 'sort_order' => 5],
            ],
            'eastern-province' => [
                ['name_ar' => 'الدمام',           'name_en' => 'Dammam',          'slug' => 'dammam',            'latitude' => 26.4207, 'longitude' => 50.0888, 'sort_order' => 1],
                ['name_ar' => 'الخبر',            'name_en' => 'Khobar',          'slug' => 'khobar',            'latitude' => 26.2172, 'longitude' => 50.1972, 'sort_order' => 2],
                ['name_ar' => 'الظهران',          'name_en' => 'Dhahran',         'slug' => 'dhahran',           'latitude' => 26.2978, 'longitude' => 50.1508, 'sort_order' => 3],
                ['name_ar' => 'الأحساء',          'name_en' => 'Al-Ahsa',         'slug' => 'al-ahsa',           'latitude' => 25.3796, 'longitude' => 49.5871, 'sort_order' => 4],
                ['name_ar' => 'الجبيل',           'name_en' => 'Jubail',          'slug' => 'jubail',            'latitude' => 27.0174, 'longitude' => 49.6580, 'sort_order' => 5],
                ['name_ar' => 'حفر الباطن',       'name_en' => 'Hafr Al-Batin',   'slug' => 'hafr-al-batin',     'latitude' => 28.4342, 'longitude' => 45.9661, 'sort_order' => 6],
                ['name_ar' => 'القطيف',           'name_en' => 'Qatif',           'slug' => 'qatif',             'latitude' => 26.5183, 'longitude' => 49.9950, 'sort_order' => 7],
                ['name_ar' => 'رأس تنورة',        'name_en' => 'Ras Tanura',      'slug' => 'ras-tanura',        'latitude' => 26.7048, 'longitude' => 50.0421, 'sort_order' => 8],
                ['name_ar' => 'الخفجي',           'name_en' => 'Khafji',          'slug' => 'khafji',            'latitude' => 28.3317, 'longitude' => 48.4882, 'sort_order' => 9],
                ['name_ar' => 'بقيق',             'name_en' => 'Buqayq',          'slug' => 'buqayq',            'latitude' => 25.9266, 'longitude' => 49.6613, 'sort_order' => 10],
            ],
            'aseer' => [
                ['name_ar' => 'أبها',             'name_en' => 'Abha',            'slug' => 'abha',              'latitude' => 18.2169, 'longitude' => 42.5053, 'sort_order' => 1],
                ['name_ar' => 'خميس مشيط',       'name_en' => 'Khamis Mushait',  'slug' => 'khamis-mushait',    'latitude' => 18.3061, 'longitude' => 42.7284, 'sort_order' => 2],
                ['name_ar' => 'بيشة',             'name_en' => 'Bishah',          'slug' => 'bishah',            'latitude' => 20.0067, 'longitude' => 42.6050, 'sort_order' => 3],
                ['name_ar' => 'النماص',           'name_en' => 'Al-Namas',        'slug' => 'al-namas',          'latitude' => 19.1266, 'longitude' => 42.1330, 'sort_order' => 4],
                ['name_ar' => 'محايل عسير',       'name_en' => 'Muhayil Asir',    'slug' => 'muhayil-asir',      'latitude' => 18.5635, 'longitude' => 42.0438, 'sort_order' => 5],
                ['name_ar' => 'ظهران الجنوب',     'name_en' => 'Dhahran Al-Janub','slug' => 'dhahran-al-janub',  'latitude' => 17.6670, 'longitude' => 43.4920, 'sort_order' => 6],
            ],
            'tabuk' => [
                ['name_ar' => 'تبوك',             'name_en' => 'Tabuk',           'slug' => 'tabuk-city',        'latitude' => 28.3835, 'longitude' => 36.5662, 'sort_order' => 1],
                ['name_ar' => 'تيماء',            'name_en' => 'Tayma',           'slug' => 'tayma',             'latitude' => 27.6311, 'longitude' => 38.5430, 'sort_order' => 2],
                ['name_ar' => 'الوجه',            'name_en' => 'Al-Wajh',         'slug' => 'al-wajh',           'latitude' => 26.2463, 'longitude' => 36.4641, 'sort_order' => 3],
                ['name_ar' => 'أملج',             'name_en' => 'Umluj',           'slug' => 'umluj',             'latitude' => 25.0428, 'longitude' => 37.2657, 'sort_order' => 4],
                ['name_ar' => 'حقل',              'name_en' => 'Haql',            'slug' => 'haql',              'latitude' => 29.2890, 'longitude' => 34.9362, 'sort_order' => 5],
            ],
            'hail' => [
                ['name_ar' => 'حائل',             'name_en' => 'Hail',            'slug' => 'hail-city',         'latitude' => 27.5219, 'longitude' => 41.7057, 'sort_order' => 1],
                ['name_ar' => 'بقعاء',            'name_en' => 'Buqa',            'slug' => 'buqa',              'latitude' => 28.3108, 'longitude' => 43.6825, 'sort_order' => 2],
                ['name_ar' => 'الغزالة',          'name_en' => 'Al-Ghazalah',     'slug' => 'al-ghazalah',       'latitude' => 26.7917, 'longitude' => 42.1750, 'sort_order' => 3],
            ],
            'northern-borders' => [
                ['name_ar' => 'عرعر',             'name_en' => 'Arar',            'slug' => 'arar',              'latitude' => 30.9753, 'longitude' => 41.0381, 'sort_order' => 1],
                ['name_ar' => 'رفحاء',            'name_en' => 'Rafha',           'slug' => 'rafha',             'latitude' => 29.6254, 'longitude' => 43.4933, 'sort_order' => 2],
                ['name_ar' => 'طريف',             'name_en' => 'Turaif',          'slug' => 'turaif',            'latitude' => 31.6822, 'longitude' => 38.6594, 'sort_order' => 3],
            ],
            'jizan' => [
                ['name_ar' => 'جازان',            'name_en' => 'Jizan',           'slug' => 'jizan-city',        'latitude' => 16.8892, 'longitude' => 42.5511, 'sort_order' => 1],
                ['name_ar' => 'صبيا',             'name_en' => 'Sabya',           'slug' => 'sabya',             'latitude' => 17.1534, 'longitude' => 42.6253, 'sort_order' => 2],
                ['name_ar' => 'أبو عريش',         'name_en' => 'Abu Arish',       'slug' => 'abu-arish',         'latitude' => 16.9716, 'longitude' => 42.7276, 'sort_order' => 3],
                ['name_ar' => 'صامطة',            'name_en' => 'Samtah',          'slug' => 'samtah',            'latitude' => 17.0433, 'longitude' => 42.9553, 'sort_order' => 4],
                ['name_ar' => 'الدرب',            'name_en' => 'Al-Darb',         'slug' => 'al-darb',           'latitude' => 17.7233, 'longitude' => 42.2525, 'sort_order' => 5],
            ],
            'najran' => [
                ['name_ar' => 'نجران',            'name_en' => 'Najran',          'slug' => 'najran-city',       'latitude' => 17.5656, 'longitude' => 44.2289, 'sort_order' => 1],
                ['name_ar' => 'شرورة',            'name_en' => 'Sharurah',        'slug' => 'sharurah',          'latitude' => 17.5116, 'longitude' => 47.1013, 'sort_order' => 2],
                ['name_ar' => 'حبونا',            'name_en' => 'Habuna',          'slug' => 'habuna',            'latitude' => 18.6083, 'longitude' => 44.8944, 'sort_order' => 3],
            ],
            'al-bahah' => [
                ['name_ar' => 'الباحة',           'name_en' => 'Al-Bahah',        'slug' => 'al-bahah-city',     'latitude' => 20.0129, 'longitude' => 41.4677, 'sort_order' => 1],
                ['name_ar' => 'بلجرشي',           'name_en' => 'Baljurashi',      'slug' => 'baljurashi',        'latitude' => 20.0867, 'longitude' => 41.5592, 'sort_order' => 2],
                ['name_ar' => 'المخواة',          'name_en' => 'Al-Mikhwah',      'slug' => 'al-mikhwah',        'latitude' => 19.9614, 'longitude' => 41.4564, 'sort_order' => 3],
            ],
            'al-jouf' => [
                ['name_ar' => 'سكاكا',            'name_en' => 'Sakaka',          'slug' => 'sakaka',            'latitude' => 29.9697, 'longitude' => 40.2002, 'sort_order' => 1],
                ['name_ar' => 'دومة الجندل',      'name_en' => 'Dumat Al-Jandal', 'slug' => 'dumat-al-jandal',   'latitude' => 29.8135, 'longitude' => 39.8749, 'sort_order' => 2],
                ['name_ar' => 'القريات',          'name_en' => 'Al-Qurayyat',     'slug' => 'al-qurayyat',       'latitude' => 31.3313, 'longitude' => 37.3487, 'sort_order' => 3],
            ],
        ];

        foreach ($data as $regionSlug => $cities) {
            $region = Region::where('slug', $regionSlug)->first();
            if (! $region) {
                continue;
            }

            foreach ($cities as $city) {
                City::firstOrCreate(
                    ['slug' => $city['slug']],
                    array_merge($city, [
                        'region_id' => $region->id,
                        'is_active' => true,
                        'ads_count' => 0,
                    ])
                );
            }
        }
    }
}
