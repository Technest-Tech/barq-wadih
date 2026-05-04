<?php

namespace Database\Seeders;

use App\Models\Ad;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\City;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdsDemoSeeder extends Seeder
{
    /**
     * Curated stable Unsplash photo URLs per category slug.
     * These are real, addressable image URLs for testing image rendering end-to-end.
     */
    private const IMAGES = [
        'cars-for-sale' => [
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=1200&q=80',
            'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=1200&q=80',
            'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80',
            'https://images.unsplash.com/photo-1542362567-b07e54358753?w=1200&q=80',
            'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?w=1200&q=80',
            'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80',
        ],
        'cars-for-rent' => [
            'https://images.unsplash.com/photo-1511919884226-fd3cad34687c?w=1200&q=80',
            'https://images.unsplash.com/photo-1546614042-7df3c24c9e5d?w=1200&q=80',
            'https://images.unsplash.com/photo-1502877338535-766e1452684a?w=1200&q=80',
        ],
        'spare-parts' => [
            'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=1200&q=80',
            'https://images.unsplash.com/photo-1597007030739-6d2e7172ee82?w=1200&q=80',
        ],
        'apartments-for-sale' => [
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200&q=80',
            'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200&q=80',
            'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200&q=80',
        ],
        'apartments-for-rent' => [
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200&q=80',
            'https://images.unsplash.com/photo-1560185007-cde436f6a4d0?w=1200&q=80',
            'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=1200&q=80',
        ],
        'villas-for-sale' => [
            'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=1200&q=80',
            'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1200&q=80',
            'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=1200&q=80',
        ],
        'land' => [
            'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
            'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1200&q=80',
        ],
        'commercial' => [
            'https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80',
            'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=1200&q=80',
        ],
        'phones-tablets' => [
            'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=1200&q=80',
            'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=1200&q=80',
            'https://images.unsplash.com/photo-1580910051074-3eb694886505?w=1200&q=80',
            'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=1200&q=80',
        ],
        'computers' => [
            'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=1200&q=80',
            'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=1200&q=80',
            'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=1200&q=80',
        ],
        'home-appliances' => [
            'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=1200&q=80',
            'https://images.unsplash.com/photo-1574269909862-7e1d70bb8078?w=1200&q=80',
        ],
        'cameras' => [
            'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=1200&q=80',
            'https://images.unsplash.com/photo-1606983340126-99ab4feaa64a?w=1200&q=80',
        ],
        'bedrooms' => [
            'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=1200&q=80',
            'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=1200&q=80',
        ],
        'living-rooms' => [
            'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1200&q=80',
            'https://images.unsplash.com/photo-1493663284031-b7e3aefcae8e?w=1200&q=80',
            'https://images.unsplash.com/photo-1567016526105-22da7c13161a?w=1200&q=80',
        ],
        'kitchens' => [
            'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=1200&q=80',
            'https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=1200&q=80',
        ],
        'office-furniture' => [
            'https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&q=80',
            'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?w=1200&q=80',
        ],
        'private-jobs' => [
            'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=1200&q=80',
            'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=1200&q=80',
        ],
        'government-jobs' => [
            'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=1200&q=80',
        ],
        'freelance' => [
            'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1200&q=80',
            'https://images.unsplash.com/photo-1531538606174-0f90ff5dce83?w=1200&q=80',
        ],
        'home-services' => [
            'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=1200&q=80',
            'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=1200&q=80',
        ],
        'education' => [
            'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=1200&q=80',
            'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?w=1200&q=80',
        ],
        'moving-shipping' => [
            'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=1200&q=80',
            'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200&q=80',
        ],
        'mens-clothing' => [
            'https://images.unsplash.com/photo-1490114538077-0a7f8cb49891?w=1200&q=80',
            'https://images.unsplash.com/photo-1593030761757-71fae45fa0e7?w=1200&q=80',
        ],
        'womens-clothing' => [
            'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=1200&q=80',
            'https://images.unsplash.com/photo-1551803091-e20673f15770?w=1200&q=80',
        ],
        'childrens-clothing' => [
            'https://images.unsplash.com/photo-1519278409-1f56fdda7fe5?w=1200&q=80',
        ],
        'accessories' => [
            'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=1200&q=80',
            'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=1200&q=80',
        ],
        'sports-leisure' => [
            'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=1200&q=80',
            'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1200&q=80',
            'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=1200&q=80',
        ],
        'books-magazines' => [
            'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=1200&q=80',
            'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=1200&q=80',
        ],
        'toys-kids' => [
            'https://images.unsplash.com/photo-1558877385-8c1f1e9b73f5?w=1200&q=80',
            'https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?w=1200&q=80',
        ],
        'animals' => [
            'https://images.unsplash.com/photo-1450778869180-41d0601e046e?w=1200&q=80',
            'https://images.unsplash.com/photo-1583511655826-05700d52f4d9?w=1200&q=80',
            'https://images.unsplash.com/photo-1425082661705-1834bfd09dca?w=1200&q=80',
        ],
        'personal-items' => [
            'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=1200&q=80',
            'https://images.unsplash.com/photo-1542272604-787c3835535d?w=1200&q=80',
        ],
    ];

    public function run(): void
    {
        if (app()->isProduction()) {
            $this->command->warn('AdsDemoSeeder skipped in production!');
            return;
        }

        $this->command->info('Seeding demo ads...');

        $sellers = $this->ensureSellers();
        $categoryIds = Category::pluck('id', 'slug');
        $cityRows = City::get(['id', 'region_id']);

        if ($cityRows->isEmpty()) {
            $this->command->error('No cities found — run CitySeeder first.');
            return;
        }

        $ads = $this->adDefinitions();

        $createdCount = 0;
        $skippedCount = 0;

        foreach ($ads as $i => $adData) {
            $slug = $adData['_slug'];
            unset($adData['_slug']);

            if (! isset($categoryIds[$slug])) {
                $skippedCount++;
                continue;
            }
            if (Ad::where('title', $adData['title'])->exists()) {
                $skippedCount++;
                continue;
            }

            $city = $cityRows->random();
            $seller = $sellers[$i % count($sellers)];

            $ad = Ad::create(array_merge([
                'user_id'           => $seller->id,
                'category_id'       => $categoryIds[$slug],
                'city_id'           => $city->id,
                'region_id'         => $city->region_id,
                'status'            => 'active',
                'moderation_status' => 'approved',
                'is_negotiable'     => true,
                'is_free'           => false,
                'pledge_accepted'   => true,
                'contact_phone'     => $seller->phone,
                'contact_whatsapp'  => $seller->phone,
                'published_at'      => now()->subMinutes(rand(5, 60 * 24 * 7)),
                'expires_at'        => now()->addDays(30),
                'views_count'       => rand(20, 1500),
                'favorites_count'   => rand(0, 80),
                'chats_count'       => rand(0, 30),
                'is_boosted'        => rand(1, 10) === 1,
            ], $adData));

            if ($ad->is_boosted) {
                $ad->boosted_until = now()->addDays(rand(2, 14));
                $ad->save();
            }

            $pool = self::IMAGES[$slug] ?? [];
            if (empty($pool)) {
                $pool = collect(self::IMAGES)->flatten()->all();
            }
            $count = min(count($pool), rand(2, 4));
            $picks = collect($pool)->shuffle()->take($count)->values();

            foreach ($picks as $idx => $url) {
                AdImage::create([
                    'ad_id'         => $ad->id,
                    'image_url'     => $url,
                    'thumbnail_url' => $url,
                    'sort_order'    => $idx,
                    'width'         => 1200,
                    'height'        => 800,
                ]);
            }

            $createdCount++;
        }

        $this->command->info("Created {$createdCount} demo ads with real images. Skipped: {$skippedCount}.");
    }

    /** @return array<int, User> */
    private function ensureSellers(): array
    {
        $defs = [
            ['email' => 'user@barqwadih.sa',    'name' => 'أحمد التجريبي', 'phone' => '+966500000002'],
            ['email' => 'seller@barqwadih.sa',  'name' => 'محمد البائع',   'phone' => '+966500000003'],
            ['email' => 'sara@barqwadih.sa',    'name' => 'سارة الخالدي',  'phone' => '+966500000004'],
            ['email' => 'khaled@barqwadih.sa',  'name' => 'خالد المطيري',  'phone' => '+966500000005'],
            ['email' => 'noura@barqwadih.sa',   'name' => 'نورة العتيبي',  'phone' => '+966500000006'],
        ];

        $users = [];
        foreach ($defs as $d) {
            $users[] = User::firstOrCreate(
                ['email' => $d['email']],
                [
                    'name'        => $d['name'],
                    'password'    => Hash::make('password'),
                    'role'        => 'user',
                    'is_active'   => true,
                    'is_verified' => true,
                    'phone'       => $d['phone'],
                    'locale'      => 'ar',
                ]
            );
        }
        return $users;
    }

    /**
     * @return list<array<string,mixed>>
     */
    private function adDefinitions(): array
    {
        return [
            // ── Cars for Sale ────────────────────────────────────────────────
            ['_slug' => 'cars-for-sale', 'title' => 'تويوتا كامري 2021 GLE - حالة ممتازة',
             'description' => "سيارة تويوتا كامري موديل 2021، فئة GLE، لون أبيض لؤلؤ.\n- المسير: 45,000 كم فقط\n- فل كامل: شاشة، كاميرا خلفية، حساسات، كروز كنترول\n- صيانة دورية بالوكالة\n- مالك أول، بدون حوادث\nالسعر قابل للتفاوض، الجادون فقط.", 'price' => 89000],

            ['_slug' => 'cars-for-sale', 'title' => 'نيسان التيما SR 2019 - نظيف جداً',
             'description' => "نيسان التيما SR موديل 2019، مسيرة 80,000 كم.\n- فحص شامل من المركز السعودي\n- بدون حوادث، صبغ الوكالة\n- جنوط رياضية، نظام صوت محسّن", 'price' => 45000, 'is_negotiable' => false],

            ['_slug' => 'cars-for-sale', 'title' => 'هيونداي توسان 2022 - تحت الضمان',
             'description' => "تاكسون 2022، 30,000 كم، تحت ضمان الوكالة حتى 2025. لون أسود، دفع رباعي.", 'price' => 110000],

            ['_slug' => 'cars-for-sale', 'title' => 'لكزس ES 350 موديل 2020',
             'description' => "لكزس ES350 فل كامل، فتحة سقف، مقاعد جلد مهواة، شاشة 12 بوصة. المسير 60,000 كم.", 'price' => 165000],

            ['_slug' => 'cars-for-sale', 'title' => 'فورد F-150 2018 - دبل',
             'description' => "فورد F-150 موديل 2018 دبل، 4WD، رفرف، حماية، حالة الجير ممتازة.", 'price' => 78000],

            ['_slug' => 'cars-for-sale', 'title' => 'مرسيدس C200 2017 AMG kit',
             'description' => "مرسيدس C200 AMG kit، فتحة، مقاعد رياضية، صيانة دورية لدى الوكالة.", 'price' => 95000],

            ['_slug' => 'cars-for-sale', 'title' => 'كيا سيراتو 2023 - شبه جديدة',
             'description' => "كيا سيراتو 2023، 8,000 كم فقط، تحت الضمان والصيانة المجانية.", 'price' => 72000],

            // ── Cars for Rent ───────────────────────────────────────────────
            ['_slug' => 'cars-for-rent', 'title' => 'هيونداي النترا 2023 للإيجار اليومي',
             'description' => "إيجار يومي/شهري، السعر يشمل التأمين الشامل و2500 كم شهرياً. التوصيل مجاني داخل الرياض.", 'price' => 110],

            ['_slug' => 'cars-for-rent', 'title' => 'تويوتا يارس 2022 إيجار شهري',
             'description' => "إيجار شهري، اقتصادية في البنزين، تشمل التأمين والصيانة. مطلوب رخصة سارية.", 'price' => 1800, 'is_negotiable' => false],

            ['_slug' => 'cars-for-rent', 'title' => 'GMC Yukon 2022 للإيجار - مناسبات',
             'description' => "إيجار يوكون لمناسبات الزفاف والرحلات العائلية. السعر يومي شامل سائق إن طلبت.", 'price' => 850],

            // ── Spare Parts ─────────────────────────────────────────────────
            ['_slug' => 'spare-parts', 'title' => 'بريك بادز أمامية أصلية - تويوتا',
             'description' => "بريك بادز أمامية أصلية تويوتا (تنطبق على كامري/كورولا 2018-2022). جديدة بالعلبة.", 'price' => 280, 'is_negotiable' => false],

            ['_slug' => 'spare-parts', 'title' => 'بطارية فارتا 90 أمبير',
             'description' => "بطارية فارتا 90 أمبير، استخدام شهرين فقط، الضمان قائم. مع كرت الضمان.", 'price' => 320],

            // ── Real Estate ─────────────────────────────────────────────────
            ['_slug' => 'apartments-for-sale', 'title' => 'شقة فاخرة بحي الياسمين - 4 غرف',
             'description' => "شقة 240م²، 4 غرف نوم + مجلس + صالة + مطبخ + 4 دورات مياه. الدور الثاني مع مصعد. تشطيب فاخر.", 'price' => 980000],

            ['_slug' => 'apartments-for-sale', 'title' => 'تمليك شقة بحي العقيق - 3 غرف',
             'description' => "شقة 180م²، 3 غرف، مدخلين، مطبخ راكب، تكييف مركزي. بالقرب من الطريق الدائري الشمالي.", 'price' => 720000],

            ['_slug' => 'apartments-for-rent', 'title' => 'شقة للإيجار حي النخيل - مفروشة',
             'description' => "شقة مؤثثة بالكامل، 4 غرف + صالة + 3 حمامات. الإيجار شهري شامل خدمات الإنترنت والكهرباء.", 'price' => 3500],

            ['_slug' => 'apartments-for-rent', 'title' => 'استوديو مفروش - حي الملز',
             'description' => "استوديو 60م² مؤثث بالكامل قريب من جامعة الإمام. إيجار شهري شامل.", 'price' => 2200],

            ['_slug' => 'villas-for-sale', 'title' => 'فيلا دوبلكس بحي الملقا - 5 غرف',
             'description' => "فيلا دوبلكس مساحة الأرض 400م²، البناء 600م². 5 غرف، 2 مجلس، مسبح، حديقة.", 'price' => 2950000],

            ['_slug' => 'villas-for-sale', 'title' => 'فيلا حديثة - حي العارض',
             'description' => "فيلا 4 غرف نوم ماستر + ملحق خارجي. تشطيب سوبر لوكس، مطبخ إيطالي.", 'price' => 1850000],

            ['_slug' => 'land', 'title' => 'أرض سكنية 600م² - حي الرمال',
             'description' => "أرض سكنية، واجهة 20م، الشارع 15م شرقي. صك إلكتروني محدث.", 'price' => 750000],

            ['_slug' => 'land', 'title' => 'أرض تجارية على شارع رئيسي',
             'description' => "أرض تجارية 800م²، واجهة على شارع رئيسي 30م. مناسبة لمعرض أو مجمع تجاري.", 'price' => 2400000],

            ['_slug' => 'commercial', 'title' => 'محل تجاري للإيجار - طريق الملك فهد',
             'description' => "محل تجاري 120م² على طريق الملك فهد. واجهة زجاجية، مكيفات مركبة، 3 حمامات.", 'price' => 95000],

            // ── Phones & Tablets ────────────────────────────────────────────
            ['_slug' => 'phones-tablets', 'title' => 'آيفون 15 برو ماكس 256 جيجا - تيتانيوم أسود',
             'description' => "آيفون 15 Pro Max 256GB، شبه جديد، استخدام أسبوعين. مع الكرتون والملحقات الأصلية.\nالضمان ساري حتى 2026.", 'price' => 5200],

            ['_slug' => 'phones-tablets', 'title' => 'سامسونج جالكسي S24 Ultra - 512',
             'description' => "S24 Ultra 512GB، رمادي، شبه جديد، الضمان من اكسترا ساري سنة. مع قلم S Pen والملحقات.", 'price' => 4800],

            ['_slug' => 'phones-tablets', 'title' => 'آيباد برو 12.9 إنش M2 - 256',
             'description' => "iPad Pro 12.9 جيل M2، 256GB، WiFi+Cellular، مع Magic Keyboard وApple Pencil 2.", 'price' => 4500],

            ['_slug' => 'phones-tablets', 'title' => 'آيفون 13 - 128 جيجا - أزرق',
             'description' => "آيفون 13 ، 128 جيجا، البطارية 92%. مستخدم بحالة ممتازة، لا توجد خدوش.", 'price' => 1850],

            // ── Computers ───────────────────────────────────────────────────
            ['_slug' => 'computers', 'title' => 'ماك بوك برو M3 14 إنش - 2024',
             'description' => "MacBook Pro 14 M3 Pro، 16GB RAM، 512GB SSD. استخدام خفيف جداً، شاشة ممتازة بدون خدوش.", 'price' => 7800, 'is_negotiable' => false],

            ['_slug' => 'computers', 'title' => 'لابتوب ASUS ROG Strix G16 - RTX 4070',
             'description' => "ASUS ROG Strix G16، Intel i9 13th، 32GB RAM، RTX 4070، 1TB SSD. مناسب للألعاب والمونتاج.", 'price' => 6500],

            ['_slug' => 'computers', 'title' => 'كمبيوتر مكتبي Gaming PC - RTX 3080',
             'description' => "تجميعة Gaming: Ryzen 7 5800X + RTX 3080 + 32GB RAM + 1TB NVMe + كيس RGB. السعر شامل الشاشة.", 'price' => 8900],

            // ── Home Appliances ─────────────────────────────────────────────
            ['_slug' => 'home-appliances', 'title' => 'ثلاجة LG ساميسايد 24 قدم',
             'description' => "ثلاجة LG side-by-side، 24 قدم، Inverter، سبيلت، ضمان 5 سنوات على المحرك.", 'price' => 3500],

            ['_slug' => 'home-appliances', 'title' => 'غسالة سامسونج 12 كجم',
             'description' => "غسالة Samsung WW12 ، 12 كجم، فتحة أمامية، AddWash، استخدام شهر فقط.", 'price' => 2400],

            // ── Cameras ─────────────────────────────────────────────────────
            ['_slug' => 'cameras', 'title' => 'كاميرا Canon EOS R6 + عدسة 24-105',
             'description' => "Canon EOS R6 mirrorless مع عدسة RF 24-105 f/4. عدد اللقطات أقل من 8000. البطاريتين والشاحن.", 'price' => 9500],

            ['_slug' => 'cameras', 'title' => 'Sony A7 III - بدن فقط',
             'description' => "Sony A7 III بدن فقط، Shutter count حوالي 12k. حالة ممتازة، مع البطارية والشاحن.", 'price' => 5800],

            // ── Furniture ───────────────────────────────────────────────────
            ['_slug' => 'bedrooms', 'title' => 'غرفة نوم تركية كاملة - خشب طبيعي',
             'description' => "غرفة نوم كاملة (سرير كينج + خزانة 6 درفات + تسريحة + كومودينو 2). خشب طبيعي تركي.", 'price' => 8500],

            ['_slug' => 'bedrooms', 'title' => 'سرير أطفال + دولاب صغير',
             'description' => "سرير أطفال خشبي مع مرتبة + دولاب صغير. الاستخدام سنة واحدة فقط، حالة ممتازة.", 'price' => 1200],

            ['_slug' => 'living-rooms', 'title' => 'كنب إيكيا KIVIK - 3 قطع رمادي',
             'description' => "كنب إيكيا KIVIK، 3 قطع، لون رمادي. اشتريته الشهر الماضي وقررت تغيير الديكور. السعر يقبل التفاوض.", 'price' => 2200],

            ['_slug' => 'living-rooms', 'title' => 'مجلس عربي مودرن - 8 جلسات',
             'description' => "مجلس عربي مودرن، 8 جلسات + ميدالية + 4 طاولات. لون بيج وبني، حالة ممتازة.", 'price' => 4500],

            ['_slug' => 'kitchens', 'title' => 'مطبخ ألمنيوم كامل - 6 متر',
             'description' => "مطبخ ألمنيوم 6 متر طولي، أبيض/خشبي، يشمل فرن وشفاط بيلت إن.", 'price' => 7200],

            ['_slug' => 'office-furniture', 'title' => 'مكتب تنفيذي خشب + كرسي جلد',
             'description' => "مكتب تنفيذي 1.8م، خشب طبيعي، مع كرسي تنفيذي جلدي وكرسيين زائرين.", 'price' => 2900],

            // ── Jobs ────────────────────────────────────────────────────────
            ['_slug' => 'private-jobs', 'title' => 'مطلوب محاسب خبرة 3 سنوات - شركة تجارية',
             'description' => "شركة تجارية بالرياض تبحث عن محاسب خبرة لا تقل عن 3 سنوات.\n- إجادة برامج المحاسبة (SAP، Oracle)\n- بكالوريوس محاسبة\n- اللغة الإنجليزية جيدة\nالراتب حسب الخبرة + بدل مواصلات + تأمين طبي.",
             'price' => null, 'is_free' => true],

            ['_slug' => 'private-jobs', 'title' => 'مطلوب مطور ويب Laravel - دوام كامل',
             'description' => "شركة ناشئة تبحث عن مطور Laravel/Vue، خبرة 2+ سنوات.\nمزايا: عمل عن بعد جزئي، أسهم في الشركة، تأمين طبي شامل.",
             'price' => null, 'is_free' => true],

            ['_slug' => 'government-jobs', 'title' => 'إعلان وظائف هيئة حكومية - تقنية معلومات',
             'description' => "هيئة حكومية تعلن عن شواغر في تقنية المعلومات بمختلف المسميات. التقديم عبر منصة جدارات حتى 10/06.",
             'price' => null, 'is_free' => true],

            ['_slug' => 'freelance', 'title' => 'مصمم جرافيك حر - تصاميم سوشيال ميديا',
             'description' => "مصمم جرافيك مستقل، 6 سنوات خبرة. تصاميم Instagram, TikTok, Snap. الباقات تبدأ من 600 ريال شهرياً.",
             'price' => 600, 'is_free' => false],

            // ── Services ────────────────────────────────────────────────────
            ['_slug' => 'home-services', 'title' => 'خدمة تنظيف منازل احترافية',
             'description' => "فريق متخصص في تنظيف المنازل والشقق والفلل. نستخدم أفضل المنظفات الآمنة. متاحون طوال الأسبوع.\nالأسعار تبدأ من 350 ريال للشقة.",
             'price' => 350, 'is_negotiable' => false],

            ['_slug' => 'home-services', 'title' => 'فني تكييف مركزي - تركيب وصيانة',
             'description' => "فني تكييف خبرة 8 سنوات، تركيب سبليت ومركزي وصيانة دورية. كشف مجاني.",
             'price' => 200],

            ['_slug' => 'education', 'title' => 'دروس خصوصية رياضيات وفيزياء',
             'description' => "معلم معتمد بخبرة 10 سنوات. أدرّس رياضيات وفيزياء للمرحلة المتوسطة والثانوية والجامعية. حضوري أو أونلاين.",
             'price' => 150, 'is_negotiable' => false],

            ['_slug' => 'education', 'title' => 'مدرس لغة إنجليزية - IELTS / TOEFL',
             'description' => "تأسيس وتدريب على اختبارات IELTS و TOEFL. مدرس حاصل على شهادة CELTA. حصص فردية أو مجموعات صغيرة.",
             'price' => 180],

            ['_slug' => 'moving-shipping', 'title' => 'نقل عفش مع الفك والتركيب',
             'description' => "شركة نقل عفش داخل الرياض وخارجها. سيارات مغلقة، فك وتركيب بأيدي خبرة، تغليف مجاني.",
             'price' => 800],

            // ── Fashion ─────────────────────────────────────────────────────
            ['_slug' => 'mens-clothing', 'title' => 'ثياب رجالية ماركة - جديدة بالعلب',
             'description' => "مجموعة ثياب رجالية من ماركات Zara و H&M مقاس L، جديدة لم تستخدم. 5 قطع.",
             'price' => 600],

            ['_slug' => 'mens-clothing', 'title' => 'بدلة رجالية رسمية كحلية - مقاس 50',
             'description' => "بدلة رجالية كحلية مقاس 50، مستخدمة مرة واحدة في زفاف. مع القميص الأبيض والكرفتة.",
             'price' => 850],

            ['_slug' => 'womens-clothing', 'title' => 'فستان سهرة - مقاس M',
             'description' => "فستان سهرة طويل لون نبيتي، مقاس M، استخدام مرة واحدة. السعر الأصلي 1800.",
             'price' => 750],

            ['_slug' => 'accessories', 'title' => 'ساعة Casio G-Shock أصلية',
             'description' => "ساعة Casio G-Shock GA-2100 أصلية مع الكرتون والضمان. حالة ممتازة.",
             'price' => 480],

            // ── Sports ──────────────────────────────────────────────────────
            ['_slug' => 'sports-leisure', 'title' => 'دراجة جبلية Trek - استخدام خفيف',
             'description' => "دراجة Trek 27.5 إنش، 21 سرعة، استخدام 3 شهور فقط. مع الإكسسوارات (لمبات، حامل، خوذة).",
             'price' => 1800],

            ['_slug' => 'sports-leisure', 'title' => 'جهاز جري NordicTrack - منزلي',
             'description' => "جهاز جري NordicTrack T6.5 ، استخدام أقل من سنة، طي سهل، شاشة ملونة.",
             'price' => 2400],

            ['_slug' => 'sports-leisure', 'title' => 'كرة قدم رسمية Adidas + شراب',
             'description' => "كرة قدم Adidas مقاس 5، رسمية، مع شراب وحماية ركب. جديدة.",
             'price' => 220, 'is_negotiable' => false],

            // ── Books ───────────────────────────────────────────────────────
            ['_slug' => 'books-magazines', 'title' => 'مجموعة كتب تطوير ذات - 12 كتاب',
             'description' => "مجموعة كتب تطوير ذات مترجمة (ستيفن كوفي، ديل كارنيجي، سيمون سينك..). 12 كتاب بحالة ممتازة.",
             'price' => 380],

            ['_slug' => 'books-magazines', 'title' => 'موسوعة الفقه الإسلامي - الكويتية',
             'description' => "الموسوعة الفقهية الكويتية، طبعة جديدة، 45 مجلد. مغلفة بالكرتون الأصلي.",
             'price' => 1500],

            // ── Toys ────────────────────────────────────────────────────────
            ['_slug' => 'toys-kids', 'title' => 'سيارة أطفال كهربائية - مرسيدس',
             'description' => "سيارة أطفال كهربائية موديل مرسيدس، تتحمل حتى 35 كجم، ريموت كنترول للوالدين.",
             'price' => 950],

            ['_slug' => 'toys-kids', 'title' => 'مجموعة ليجو ستار وورز',
             'description' => "Lego Star Wars Millennium Falcon، 1351 قطعة، جديدة بالعلبة لم تفتح.",
             'price' => 1100, 'is_negotiable' => false],

            // ── Animals ─────────────────────────────────────────────────────
            ['_slug' => 'animals', 'title' => 'فرس عربي أصيل - 4 سنوات',
             'description' => "فرس عربي أصيل مسجل في جمعية المربين، عمر 4 سنوات. مدرب على الركوب، مع الشهادات.",
             'price' => 65000],

            ['_slug' => 'animals', 'title' => 'صقر حر مدرب',
             'description' => "صقر حر مدرب على القنص، عمر سنتين، مع الجاذي والكاب والمرسلات.",
             'price' => 12000],

            ['_slug' => 'animals', 'title' => 'طيور حسون أوربية - أصلية',
             'description' => "طيور حسون أوربية، ذكور وإناث، أصلية. السعر للطير الواحد. متاحة الآن.",
             'price' => 850],

            // ── Personal items ──────────────────────────────────────────────
            ['_slug' => 'personal-items', 'title' => 'حقيبة سفر سامسونايت كبيرة',
             'description' => "حقيبة سفر Samsonite مقاس 28 إنش، استخدام مرتين فقط، عجلات سبيكة سليمة.",
             'price' => 480],

            ['_slug' => 'personal-items', 'title' => 'نظارات شمسية Ray-Ban أصلية',
             'description' => "نظارات Ray-Ban Aviator أصلية، مع الكرتون والشهادة. اشتريت من فرع الرياض جاليري.",
             'price' => 650],
        ];
    }
}
