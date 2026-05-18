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
        // Wipe & re-seed so images are always fresh on re-run
        Banner::truncate();

        $banners = [
            // ── Home Top carousel (two rotating slides) ──────────────────
            [
                'title'            => 'عروض السيارات — أفضل الأسعار',
                'image_url'        => 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1400&h=400&fit=crop&q=80',
                'image_url_mobile' => 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=800&h=400&fit=crop&q=80',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => '/ar/categories/cars',
                'position'         => BannerPosition::HomeTop->value,
                'sort_order'       => 0,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'شركة مثال للسيارات',
                'advertiser_phone' => '966500000001',
            ],
            [
                'title'            => 'أحدث الهواتف والأجهزة الإلكترونية',
                'image_url'        => 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=1400&h=400&fit=crop&q=80',
                'image_url_mobile' => 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=800&h=400&fit=crop&q=80',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => '/ar/categories/electronics',
                'position'         => BannerPosition::HomeTop->value,
                'sort_order'       => 2,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'متجر التقنية',
                'advertiser_phone' => '966500000003',
            ],

            // ── Home Middle (single banner between feed sections) ─────────
            [
                'title'            => 'أثاث فاخر — تصاميم عصرية',
                'image_url'        => 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=1400&h=300&fit=crop&q=80',
                'image_url_mobile' => 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800&h=300&fit=crop&q=80',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => '/ar/categories/furniture',
                'position'         => BannerPosition::HomeMiddle->value,
                'sort_order'       => 0,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'معرض المنزل الحديث',
                'advertiser_phone' => '966500000004',
            ],
            [
                'title'            => 'أزياء الموسم — تخفيضات تصل 50%',
                'image_url'        => 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=1400&h=300&fit=crop&q=80',
                'image_url_mobile' => 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=800&h=300&fit=crop&q=80',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => '/ar/categories/fashion',
                'position'         => BannerPosition::HomeMiddle->value,
                'sort_order'       => 1,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'بوتيك الأناقة',
                'advertiser_phone' => '966500000005',
            ],

            // ── Category Top (shown inside category pages) ────────────────
            [
                'title'            => 'وظائف جديدة — قدّم الآن',
                'image_url'        => 'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=1400&h=250&fit=crop&q=80',
                'image_url_mobile' => 'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=800&h=250&fit=crop&q=80',
                'link_type'        => BannerLinkType::Url->value,
                'link_url'         => '/ar/categories/jobs',
                'position'         => BannerPosition::CategoryTop->value,
                'sort_order'       => 0,
                'starts_at'        => now(),
                'ends_at'          => now()->addMonths(3),
                'is_active'        => true,
                'advertiser_name'  => 'منصة التوظيف',
                'advertiser_phone' => '966500000006',
            ],
        ];

        foreach ($banners as $banner) {
            Banner::create($banner);
        }
    }
}
