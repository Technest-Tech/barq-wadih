<?php

namespace Database\Seeders;

use App\Models\City;
use App\Models\District;
use Illuminate\Database\Seeder;

/**
 * Seeds districts (أحياء) for the top 5 Saudi cities. Other cities are left
 * empty on purpose so the post-ad wizard falls back to a free-text district
 * input — adding them is an admin task, not a deploy-blocker.
 */
class DistrictSeeder extends Seeder
{
    public function run(): void
    {
        // [city_slug => [['name_ar', 'name_en'], ...]]
        $data = [
            // ── Riyadh ──────────────────────────────────────────────────────
            'riyadh-city' => [
                ['الملز',         'Al-Malaz'],
                ['العليا',        'Al-Olaya'],
                ['السليمانية',    'Al-Sulaimaniyah'],
                ['الورود',        'Al-Wurud'],
                ['الياسمين',      'Al-Yasmin'],
                ['النرجس',        'Al-Narjis'],
                ['الملقا',        'Al-Malqa'],
                ['حطين',          'Hittin'],
                ['الصحافة',       'Al-Sahafa'],
                ['الندى',         'Al-Nada'],
                ['غرناطة',        'Granada'],
                ['الروضة',        'Al-Rawdah'],
                ['النسيم',        'Al-Naseem'],
                ['الخليج',        'Al-Khaleej'],
                ['العزيزية',      'Al-Aziziyah'],
                ['شبرا',          'Shubra'],
                ['البديعة',       'Al-Badiah'],
                ['الديرة',        'Al-Deerah'],
                ['الربوة',        'Al-Rabwah'],
                ['الفلاح',        'Al-Falah'],
                ['الصحافة',       'Al-Sahafah'],
                ['قرطبة',         'Cordoba'],
                ['الازدهار',      'Al-Izdihar'],
                ['الفيحاء',       'Al-Fayha'],
                ['الروابي',       'Al-Rawabi'],
            ],
            // ── Jeddah (under both regions; pick the Makkah one) ─────────────
            'jeddah-makkah' => [
                ['الروضة',        'Al-Rawdah'],
                ['الزهراء',       'Al-Zahra'],
                ['الصفا',         'Al-Safa'],
                ['الشاطئ',        'Al-Shati'],
                ['الحمراء',       'Al-Hamra'],
                ['البساتين',      'Al-Basateen'],
                ['النسيم',        'Al-Naseem'],
                ['النعيم',        'Al-Naeem'],
                ['الفيصلية',      'Al-Faisaliyah'],
                ['البوادي',       'Al-Bawadi'],
                ['الأندلس',       'Al-Andalus'],
                ['السلامة',       'Al-Salamah'],
                ['المروة',        'Al-Marwah'],
                ['أبحر الشمالية', 'North Obhur'],
                ['أبحر الجنوبية', 'South Obhur'],
                ['البلد',         'Al-Balad'],
                ['الكندرة',       'Al-Kandara'],
                ['النزهة',        'Al-Nuzha'],
                ['الواحة',        'Al-Wahah'],
                ['الجامعة',       'Al-Jameah'],
            ],
            // Some tenants also use the Riyadh-region jeddah row; mirror minimally.
            'jeddah' => [
                ['الروضة',        'Al-Rawdah'],
                ['الصفا',         'Al-Safa'],
                ['الشاطئ',        'Al-Shati'],
                ['الحمراء',       'Al-Hamra'],
                ['البساتين',      'Al-Basateen'],
                ['الأندلس',       'Al-Andalus'],
                ['السلامة',       'Al-Salamah'],
                ['أبحر الشمالية', 'North Obhur'],
            ],
            // ── Dammam ──────────────────────────────────────────────────────
            'dammam' => [
                ['الفيصلية',      'Al-Faisaliyah'],
                ['الشاطئ',        'Al-Shati'],
                ['النور',         'Al-Noor'],
                ['الراكة',        'Al-Rakah'],
                ['الجلوية',       'Al-Jalawiyah'],
                ['الأمانة',       'Al-Amanah'],
                ['الفردوس',       'Al-Firdous'],
                ['الإسكان',       'Al-Iskan'],
                ['الواحة',        'Al-Wahah'],
                ['الزهور',        'Al-Zuhour'],
                ['الإحساء',       'Al-Ahsa'],
                ['البديع',        'Al-Badi'],
                ['الخليج',        'Al-Khaleej'],
                ['ضاحية الملك فهد','King Fahd Suburb'],
                ['الأثير',        'Al-Atheer'],
                ['الشعلة',        'Al-Shulah'],
                ['الواحة',        'Al-Wahah'],
                ['الناصرية',      'Al-Nasiriyah'],
            ],
            // ── Mecca ───────────────────────────────────────────────────────
            'makkah-city' => [
                ['العزيزية',      'Al-Aziziyah'],
                ['الششة',         'Al-Sheshah'],
                ['النسيم',        'Al-Naseem'],
                ['العوالي',       'Al-Awali'],
                ['الزاهر',        'Al-Zahir'],
                ['الزيمة',        'Al-Zaymah'],
                ['التنعيم',       'Al-Tan\'eem'],
                ['الشوقية',       'Al-Shawqiyah'],
                ['الكعكية',       'Al-Ka\'kiyah'],
                ['بطحاء قريش',    'Bat-ha Quraish'],
                ['البيبان',        'Al-Bayban'],
                ['الجموم',        'Al-Jumum'],
                ['الرصيفة',       'Al-Rusayfah'],
                ['الشهداء',       'Al-Shuhada'],
                ['المسفلة',       'Al-Misfalah'],
            ],
            // ── Medina ──────────────────────────────────────────────────────
            'madinah-city' => [
                ['العوالي',       'Al-Awali'],
                ['قباء',          'Quba'],
                ['الحرة الشرقية', 'Eastern Harrah'],
                ['الحرة الغربية', 'Western Harrah'],
                ['شظاة',          'Shazah'],
                ['العنابس',       'Al-Anabis'],
                ['طيبة',          'Taybah'],
                ['السلام',        'Al-Salam'],
                ['الرانوناء',     'Al-Ranuna'],
                ['العوالي',       'Al-Awali'],
                ['المبعوث',       'Al-Mab\'uth'],
                ['الجرف',         'Al-Jurf'],
                ['الدويخلة',      'Al-Duwaykhilah'],
                ['الفيصلية',      'Al-Faisaliyah'],
                ['الراية',        'Al-Rayah'],
            ],
        ];

        foreach ($data as $citySlug => $districts) {
            $city = City::where('slug', $citySlug)->first();
            if (! $city) {
                continue;
            }

            $sort = 0;
            foreach ($districts as [$ar, $en]) {
                $slug = \Illuminate\Support\Str::slug($en);
                District::firstOrCreate(
                    ['city_id' => $city->id, 'slug' => $slug],
                    [
                        'region_id'  => $city->region_id,
                        'name_ar'    => $ar,
                        'name_en'    => $en,
                        'is_active'  => true,
                        'sort_order' => ++$sort,
                    ]
                );
            }
        }
    }
}
