<?php

namespace Database\Seeders;

use App\Models\Ad;
use App\Models\AdImage;
use App\Models\User;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdsDemoSeeder extends Seeder
{
    public function run(): void
    {
        if (app()->isProduction()) {
            $this->command->warn('AdsDemoSeeder skipped in production!');
            return;
        }

        $this->command->info('Seeding demo ads...');

        // Ensure demo user exists
        $user = User::firstOrCreate(
            ['email' => 'user@barqwadih.sa'],
            [
                'name'        => 'أحمد التجريبي',
                'password'    => Hash::make('password'),
                'role'        => 'user',
                'is_active'   => true,
                'is_verified' => true,
                'phone'       => '+966500000002',
                'locale'      => 'ar',
            ]
        );

        $user2 = User::firstOrCreate(
            ['email' => 'seller@barqwadih.sa'],
            [
                'name'        => 'محمد البائع',
                'password'    => Hash::make('password'),
                'role'        => 'user',
                'is_active'   => true,
                'is_verified' => true,
                'phone'       => '+966500000003',
                'locale'      => 'ar',
            ]
        );

        $expiresAt = now()->addDays(30);
        $ads = [
            // Cars category (id=1)
            [
                'user_id'          => $user->id,
                'category_id'      => 1,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'تويوتا كامري 2021 للبيع - حالة ممتازة',
                'description'      => 'سيارة تويوتا كامري موديل 2021، لون أبيض لؤلؤ، مسيرة 45,000 كم فقط. فل كامل، كاميرا خلفية، شاشة تاتش. لا تفوتك الفرصة.',
                'price'            => 89000,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(2),
                'expires_at'       => $expiresAt,
                'contact_phone'    => '+966500000002',
            ],
            [
                'user_id'          => $user2->id,
                'category_id'      => 1,
                'city_id'          => 2,
                'region_id'        => 2,
                'title'            => 'نيسان التيما SR 2019 - نظيف جداً',
                'description'      => 'نيسان التيما SR موديل 2019، مسيرة 80,000 كم، فحص كامل، بدون حوادث. السعر 45,000 غير قابل للتفاوض.',
                'price'            => 45000,
                'is_negotiable'    => false,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(5),
                'contact_phone'    => '+966500000003',
            ],
            [
                'user_id'          => $user->id,
                'category_id'      => 1,
                'city_id'          => 4,
                'region_id'        => 5,
                'title'            => 'هيونداي تاكسون 2022 - ضمان الوكالة',
                'description'      => 'هيونداي تاكسون موديل 2022، مسيرة 30,000 كم، لا تزال تحت ضمان الوكالة حتى 2025.',
                'price'            => 110000,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subDays(1),
                'contact_phone'    => '+966500000002',
            ],
            // Electronics category (id=12)
            [
                'user_id'          => $user2->id,
                'category_id'      => 12,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'آيفون 15 برو ماكس - 256 جيجا جديد',
                'description'      => 'آيفون 15 برو ماكس لون تيتانيوم أسود، 256 جيجا، مع الكرتون والملحقات الأصلية. لم يستخدم إلا أسبوعين.',
                'price'            => 5200,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subMinutes(30),
                'contact_phone'    => '+966500000003',
            ],
            [
                'user_id'          => $user->id,
                'category_id'      => 12,
                'city_id'          => 3,
                'region_id'        => 1,
                'title'            => 'ماك بوك برو M3 - 2024',
                'description'      => 'ماك بوك برو 14 بوصة، شريحة M3، رام 16 جيجا، 512 SSD. استخدام خفيف، شاشة مثالية بلا خدوش.',
                'price'            => 7800,
                'is_negotiable'    => false,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(3),
                'contact_phone'    => '+966500000002',
            ],
            // Furniture category (id=18)
            [
                'user_id'          => $user2->id,
                'category_id'      => 18,
                'city_id'          => 2,
                'region_id'        => 2,
                'title'            => 'غرفة نوم كاملة - خشب طبيعي',
                'description'      => 'غرفة نوم كاملة مكونة من سرير كينج + خزانة + تسريحة + 2 كومودينو. خشب طبيعي عالي الجودة. حالة ممتازة.',
                'price'            => 8500,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subDays(2),
                'contact_phone'    => '+966500000003',
            ],
            [
                'user_id'          => $user->id,
                'category_id'      => 18,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'كنب إيكيا 3 قطع - مستخدم شهر',
                'description'      => 'كنب إيكيا من موديل كيفيك، لون رمادي، 3 قطع. اشتريته الشهر الماضي وقررت تغيير الديكور.',
                'price'            => 2200,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(8),
                'contact_phone'    => '+966500000002',
            ],
            // Real Estate category (id=6)
            [
                'user_id'          => $user2->id,
                'category_id'      => 6,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'شقة للإيجار - حي النخيل - 4 غرف',
                'description'      => 'شقة مؤثثة بالكامل، 4 غرف + صالة + مطبخ + 3 دورات مياه. حي النخيل، قريبة من المدارس والخدمات.',
                'price'            => 3500,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(12),
                'contact_phone'    => '+966500000003',
            ],
            [
                'user_id'          => $user->id,
                'category_id'      => 6,
                'city_id'          => 2,
                'region_id'        => 2,
                'title'            => 'أرض للبيع - حي الغامدي - 600 م²',
                'description'      => 'أرض سكنية 600 متر مربع، واجهة 20م، في حي الغامدي. الأوراق كاملة ومحررة.',
                'price'            => 750000,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subDays(3),
                'contact_phone'    => '+966500000002',
            ],
            // Jobs category (id=23)
            [
                'user_id'          => $user2->id,
                'category_id'      => 23,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'مطلوب محاسب خبرة 3 سنوات - شركة تجارية',
                'description'      => 'شركة تجارية بالرياض تبحث عن محاسب بخبرة لا تقل عن 3 سنوات. يشترط إجادة برامج المحاسبة.',
                'price'            => null,
                'is_negotiable'    => false,
                'is_free'          => true,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(6),
                'contact_phone'    => '+966500000003',
            ],
            // Services category (id=28)
            [
                'user_id'          => $user->id,
                'category_id'      => 28,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'خدمة تنظيف منازل احترافية',
                'description'      => 'فريق متخصص في تنظيف المنازل والشقق والفلل. نستخدم أفضل المنظفات. متاحون طوال الأسبوع.',
                'price'            => 350,
                'is_negotiable'    => false,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subDays(1),
                'contact_phone'    => '+966500000002',
            ],
            [
                'user_id'          => $user2->id,
                'category_id'      => 28,
                'city_id'          => 2,
                'region_id'        => 2,
                'title'            => 'دروس خصوصية رياضيات وفيزياء',
                'description'      => 'معلم معتمد بخبرة 10 سنوات. أدرّس رياضيات وفيزياء للمراحل المتوسطة والثانوية والجامعية.',
                'price'            => 150,
                'is_negotiable'    => false,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(4),
                'contact_phone'    => '+966500000003',
            ],
            // Fashion category (id=33)
            [
                'user_id'          => $user->id,
                'category_id'      => 33,
                'city_id'          => 3,
                'region_id'        => 1,
                'title'            => 'ثياب رجالية براند - جديدة بالعلب',
                'description'      => 'مجموعة ثياب رجالية من ماركة Zara و H&M، مقاس L، جديدة لم تستخدم. 5 قطع بسعر الجملة.',
                'price'            => 600,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(9),
                'contact_phone'    => '+966500000002',
            ],
            // Sports (id=38)
            [
                'user_id'          => $user2->id,
                'category_id'      => 38,
                'city_id'          => 1,
                'region_id'        => 1,
                'title'            => 'دراجة جبلية Trek - استخدام خفيف',
                'description'      => 'دراجة جبلية Trek مقاس 27.5، 21 سرعة. استخدام 3 شهور فقط، حالة شبه جديدة، مع الإكسسوارات.',
                'price'            => 1800,
                'is_negotiable'    => true,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subDays(2),
                'contact_phone'    => '+966500000003',
            ],
            // Animals (id=41)
            [
                'user_id'          => $user->id,
                'category_id'      => 41,
                'city_id'          => 2,
                'region_id'        => 2,
                'title'            => 'جرو هاسكي سيبيري - شهرين',
                'description'      => 'جرو هاسكي أصيل عمره شهرين، محصّن، مع شهادة ميلاد. اللون رمادي وأبيض. للعائلات فقط.',
                'price'            => 2500,
                'is_negotiable'    => false,
                'is_free'          => false,
                'status'           => 'active',
                'moderation_status'=> 'approved',
                'published_at'     => now()->subHours(7),
                'contact_phone'    => '+966500000002',
            ],
        ];

        $demoImages = [
            '1.jpeg', '2.jpeg', '3.jpeg', '4.jpeg', '5.jpeg', '7.jpeg',
            '8.jpeg', '9.jpeg', '11.jpeg', '12.jpeg', '13.jpeg', '20.jpeg',
            '21.jpeg', '22.jpeg', '23.jpeg', '24.jpeg'
        ];

        $createdCount = 0;
        foreach ($ads as $adData) {
            // Skip if similar title already exists
            if (Ad::where('title', $adData['title'])->exists()) {
                continue;
            }
            // Ensure required expires_at field is always set
            $ad = Ad::create(array_merge(['expires_at' => $expiresAt], $adData));
            
            // Assign random images
            $numImages = rand(1, 3);
            $selectedImages = collect($demoImages)->shuffle()->take($numImages)->values();
            
            foreach ($selectedImages as $index => $img) {
                $url = asset('/storage/demo_ads/' . $img);
                \App\Models\AdImage::create([
                    'ad_id'         => $ad->id,
                    'image_url'     => $url,
                    'thumbnail_url' => $url,
                    'sort_order'    => $index,
                ]);
            }

            $createdCount++;
        }

        $this->command->info("Created {$createdCount} demo ads with real images.");
    }
}
