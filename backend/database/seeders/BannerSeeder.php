<?php

namespace Database\Seeders;

use App\Enums\BannerLinkType;
use App\Enums\BannerPosition;
use App\Models\Banner;
use Illuminate\Database\Seeder;

class BannerSeeder extends Seeder
{
    public function run(): void
    {
        $banners = [
            [
                'title'            => 'عروض السيارات — خصم حتى 30%',
                'image_url'        => 'https://placehold.co/1200x300/1B3A6B/ffffff?text=%D8%B9%D8%B1%D9%88%D8%B6+%D8%A7%D9%84%D8%B3%D9%8A%D8%A7%D8%B1%D8%A7%D8%AA',
                'image_url_mobile' => 'https://placehold.co/800x400/1B3A6B/ffffff?text=%D8%B9%D8%B1%D9%88%D8%B6+%D8%A7%D9%84%D8%B3%D9%8A%D8%A7%D8%B1%D8%A7%D8%AA',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => 'https://barqwadih.com',
                'position'         => BannerPosition::HomeTop->value,
                'sort_order'       => 0,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'شركة مثال للسيارات',
                'advertiser_phone' => '966500000001',
            ],
            [
                'title'            => 'عقارات الرياض — شقق وفلل للبيع',
                'image_url'        => 'https://placehold.co/1200x300/0B8457/ffffff?text=%D8%B9%D9%82%D8%A7%D8%B1%D8%A7%D8%AA+%D8%A7%D9%84%D8%B1%D9%8A%D8%A7%D8%B6',
                'image_url_mobile' => 'https://placehold.co/800x400/0B8457/ffffff?text=%D8%B9%D9%82%D8%A7%D8%B1%D8%A7%D8%AA+%D8%A7%D9%84%D8%B1%D9%8A%D8%A7%D8%B6',
                'link_type'        => BannerLinkType::Whatsapp->value,
                'link_whatsapp'    => '966500000002',
                'position'         => BannerPosition::HomeTop->value,
                'sort_order'       => 1,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'مكتب الأمل العقاري',
                'advertiser_phone' => '966500000002',
            ],
            [
                'title'            => 'أجهزة إلكترونية بأفضل الأسعار',
                'image_url'        => 'https://placehold.co/1200x200/7C3AED/ffffff?text=%D8%A3%D8%AC%D9%87%D8%B2%D8%A9+%D8%A5%D9%84%D9%83%D8%AA%D8%B1%D9%88%D9%86%D9%8A%D8%A9',
                'image_url_mobile' => 'https://placehold.co/800x300/7C3AED/ffffff?text=%D8%A3%D8%AC%D9%87%D8%B2%D8%A9+%D8%A5%D9%84%D9%83%D8%AA%D8%B1%D9%88%D9%86%D9%8A%D8%A9',
                'link_type'        => BannerLinkType::None->value,
                'position'         => BannerPosition::HomeMiddle->value,
                'sort_order'       => 0,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'متجر التقنية',
                'advertiser_phone' => '966500000003',
            ],
            [
                'title'            => 'تأمين سيارات — أفضل العروض',
                'image_url'        => 'https://placehold.co/1200x200/DC2626/ffffff?text=%D8%AA%D8%A3%D9%85%D9%8A%D9%86+%D8%B3%D9%8A%D8%A7%D8%B1%D8%A7%D8%AA',
                'image_url_mobile' => 'https://placehold.co/800x300/DC2626/ffffff?text=%D8%AA%D8%A3%D9%85%D9%8A%D9%86+%D8%B3%D9%8A%D8%A7%D8%B1%D8%A7%D8%AA',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => 'https://barqwadih.com',
                'position'         => BannerPosition::CategoryTop->value,
                'sort_order'       => 0,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'شركة تأمين نجم',
                'advertiser_phone' => '966500000004',
            ],
        ];

        foreach ($banners as $banner) {
            Banner::create($banner);
        }
    }
}
