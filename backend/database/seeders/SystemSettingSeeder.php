<?php

namespace Database\Seeders;

use App\Models\SystemSetting;
use Illuminate\Database\Seeder;

class SystemSettingSeeder extends Seeder
{
    public function run(): void
    {
        $settings = [
            // Commission settings
            [
                'key'         => 'commission_rate',
                'value'       => '0.005',
                'type'        => 'decimal',
                'group'       => 'commission',
                'description' => 'Global commission rate (0.5% of sale price)',
            ],
            [
                'key'         => 'dealer_flat_fee',
                'value'       => '90',
                'type'        => 'decimal',
                'group'       => 'commission',
                'description' => 'Flat commission fee for dealers in SAR',
            ],

            // Ad lifecycle settings
            [
                'key'         => 'ad_expiry_days',
                'value'       => '30',
                'type'        => 'integer',
                'group'       => 'ads',
                'description' => 'Number of days before an ad expires',
            ],
            [
                'key'         => 'expiry_notify_days',
                'value'       => '3',
                'type'        => 'integer',
                'group'       => 'ads',
                'description' => 'Days before expiry to send pre-expiry notification',
            ],
            [
                'key'         => 'max_images_per_ad',
                'value'       => '10',
                'type'        => 'integer',
                'group'       => 'ads',
                'description' => 'Maximum number of images allowed per ad',
            ],

            // Content settings
            [
                'key'   => 'disclaimer_text_ar',
                'value' => 'برق واضح مجرد منصة وسيطة بين البائع والمشتري ولا تتحمل أي مسؤولية قانونية أو مالية عن الصفقات التي تتم بين المستخدمين. يتحمل المستخدم كامل المسؤولية عن صحة المعلومات المنشورة والتزامه بالأنظمة والقوانين المعمول بها في المملكة العربية السعودية.',
                'type'  => 'string',
                'group' => 'content',
                'description' => 'Legal disclaimer shown on all ad pages (Arabic)',
            ],
            [
                'key'   => 'disclaimer_text_en',
                'value' => 'Barq Wadih is merely an intermediary platform between buyers and sellers and bears no legal or financial responsibility for transactions between users. The user bears full responsibility for the accuracy of published information and compliance with applicable laws and regulations in Saudi Arabia.',
                'type'  => 'string',
                'group' => 'content',
                'description' => 'Legal disclaimer shown on all ad pages (English)',
            ],
            [
                'key'   => 'pledge_text_ar',
                'value' => 'أتعهد بأن المعلومات الواردة في هذا الإعلان صحيحة ودقيقة، وأن السلعة أو الخدمة المعروضة مشروعة ولا تخالف أحكام الشريعة الإسلامية والأنظمة المعمول بها في المملكة العربية السعودية، وأتحمل كامل المسؤولية القانونية والشرعية عن محتوى هذا الإعلان.',
                'type'  => 'string',
                'group' => 'content',
                'description' => 'Ethical pledge text shown before posting an ad (Arabic)',
            ],
            [
                'key'   => 'pledge_text_en',
                'value' => 'I pledge that the information in this ad is true and accurate, that the item or service offered is lawful and does not violate Islamic law or regulations applicable in Saudi Arabia, and I bear full legal and religious responsibility for the content of this ad.',
                'type'  => 'string',
                'group' => 'content',
                'description' => 'Ethical pledge text shown before posting an ad (English)',
            ],

            // Trust settings
            [
                'key'         => 'verified_badge_threshold',
                'value'       => '5',
                'type'        => 'integer',
                'group'       => 'trust',
                'description' => 'Number of paid commissions required to auto-grant verified badge',
            ],

            // Boost settings
            [
                'key'         => 'boost_premium_duration_hours',
                'value'       => '72',
                'type'        => 'integer',
                'group'       => 'boost',
                'description' => 'Duration of a premium boost in hours (default 3 days)',
            ],
            [
                'key'         => 'boost_premium_price',
                'value'       => '0',
                'type'        => 'decimal',
                'group'       => 'boost',
                'description' => 'Price of a premium boost in SAR (0 = free during beta)',
            ],
            [
                'key'         => 'boost_refresh_cooldown_hours',
                'value'       => '24',
                'type'        => 'integer',
                'group'       => 'boost',
                'description' => 'Minimum hours between refreshes for the same ad',
            ],
            [
                'key'         => 'boost_max_active_per_user',
                'value'       => '5',
                'type'        => 'integer',
                'group'       => 'boost',
                'description' => 'Maximum number of concurrently boosted ads per user',
            ],
        ];

        foreach ($settings as $setting) {
            SystemSetting::firstOrCreate(
                ['key' => $setting['key']],
                $setting
            );
        }
    }
}
