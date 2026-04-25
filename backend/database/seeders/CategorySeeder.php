<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            [
                'name_ar'     => 'سيارات',
                'name_en'     => 'Cars',
                'slug'        => 'cars',
                'icon'        => '🚗',
                'sort_order'  => 1,
                'is_free'     => false,
                'commission_rate' => null, // uses global
                'prohibited_keywords' => [],
                'children'    => [
                    ['name_ar' => 'سيارات للبيع',     'name_en' => 'Cars for Sale',      'slug' => 'cars-for-sale',     'sort_order' => 1],
                    ['name_ar' => 'سيارات للإيجار',   'name_en' => 'Cars for Rent',      'slug' => 'cars-for-rent',     'sort_order' => 2],
                    ['name_ar' => 'قطع غيار',          'name_en' => 'Spare Parts',        'slug' => 'spare-parts',       'sort_order' => 3],
                    ['name_ar' => 'خدمات السيارات',    'name_en' => 'Car Services',       'slug' => 'car-services',      'sort_order' => 4],
                ],
            ],
            [
                'name_ar'    => 'عقارات',
                'name_en'    => 'Real Estate',
                'slug'       => 'real-estate',
                'icon'       => '🏠',
                'sort_order' => 2,
                'is_free'    => false,
                'children'   => [
                    ['name_ar' => 'شقق للبيع',       'name_en' => 'Apartments for Sale', 'slug' => 'apartments-for-sale', 'sort_order' => 1],
                    ['name_ar' => 'شقق للإيجار',     'name_en' => 'Apartments for Rent', 'slug' => 'apartments-for-rent', 'sort_order' => 2],
                    ['name_ar' => 'فلل للبيع',        'name_en' => 'Villas for Sale',    'slug' => 'villas-for-sale',     'sort_order' => 3],
                    ['name_ar' => 'أراضي',            'name_en' => 'Land',               'slug' => 'land',                'sort_order' => 4],
                    ['name_ar' => 'مكاتب وتجاري',    'name_en' => 'Commercial',          'slug' => 'commercial',          'sort_order' => 5],
                ],
            ],
            [
                'name_ar'    => 'إلكترونيات',
                'name_en'    => 'Electronics',
                'slug'       => 'electronics',
                'icon'       => '📱',
                'sort_order' => 3,
                'is_free'    => false,
                'children'   => [
                    ['name_ar' => 'هواتف وأجهزة لوحية', 'name_en' => 'Phones & Tablets',   'slug' => 'phones-tablets',   'sort_order' => 1],
                    ['name_ar' => 'حاسبات وأجهزة',       'name_en' => 'Computers',          'slug' => 'computers',        'sort_order' => 2],
                    ['name_ar' => 'أجهزة منزلية',         'name_en' => 'Home Appliances',    'slug' => 'home-appliances',  'sort_order' => 3],
                    ['name_ar' => 'كاميرات',              'name_en' => 'Cameras',            'slug' => 'cameras',          'sort_order' => 4],
                    ['name_ar' => 'إلكترونيات أخرى',     'name_en' => 'Other Electronics',  'slug' => 'other-electronics', 'sort_order' => 5],
                ],
            ],
            [
                'name_ar'    => 'أثاث ومفروشات',
                'name_en'    => 'Furniture',
                'slug'       => 'furniture',
                'icon'       => '🛋️',
                'sort_order' => 4,
                'is_free'    => false,
                'children'   => [
                    ['name_ar' => 'غرف نوم',       'name_en' => 'Bedrooms',     'slug' => 'bedrooms',      'sort_order' => 1],
                    ['name_ar' => 'غرف جلوس',      'name_en' => 'Living Rooms', 'slug' => 'living-rooms',  'sort_order' => 2],
                    ['name_ar' => 'مطابخ',          'name_en' => 'Kitchens',     'slug' => 'kitchens',      'sort_order' => 3],
                    ['name_ar' => 'أثاث مكتبي',    'name_en' => 'Office Furniture', 'slug' => 'office-furniture', 'sort_order' => 4],
                ],
            ],
            [
                'name_ar'    => 'وظائف',
                'name_en'    => 'Jobs',
                'slug'       => 'jobs',
                'icon'       => '💼',
                'sort_order' => 5,
                'is_free'    => true, // No commission for jobs
                'children'   => [
                    ['name_ar' => 'وظائف حكومية',  'name_en' => 'Government Jobs',   'slug' => 'government-jobs',   'sort_order' => 1],
                    ['name_ar' => 'وظائف خاصة',    'name_en' => 'Private Jobs',      'slug' => 'private-jobs',      'sort_order' => 2],
                    ['name_ar' => 'عمل حر',         'name_en' => 'Freelance',         'slug' => 'freelance',         'sort_order' => 3],
                    ['name_ar' => 'ابحث عن موظف',   'name_en' => 'Seeking Employee',  'slug' => 'seeking-employee',  'sort_order' => 4],
                ],
            ],
            [
                'name_ar'    => 'خدمات',
                'name_en'    => 'Services',
                'slug'       => 'services',
                'icon'       => '🔧',
                'sort_order' => 6,
                'is_free'    => false,
                'children'   => [
                    ['name_ar' => 'خدمات منزلية',    'name_en' => 'Home Services',    'slug' => 'home-services',    'sort_order' => 1],
                    ['name_ar' => 'تعليم ودروس',     'name_en' => 'Education',        'slug' => 'education',        'sort_order' => 2],
                    ['name_ar' => 'نقل وشحن',        'name_en' => 'Moving & Shipping', 'slug' => 'moving-shipping', 'sort_order' => 3],
                    ['name_ar' => 'خدمات أخرى',      'name_en' => 'Other Services',   'slug' => 'other-services',   'sort_order' => 4],
                ],
            ],
            [
                'name_ar'    => 'أزياء وملابس',
                'name_en'    => 'Fashion',
                'slug'       => 'fashion',
                'icon'       => '👗',
                'sort_order' => 7,
                'is_free'    => false,
                'children'   => [
                    ['name_ar' => 'ملابس رجالية',   'name_en' => "Men's Clothing",   'slug' => 'mens-clothing',   'sort_order' => 1],
                    ['name_ar' => 'ملابس نسائية',   'name_en' => "Women's Clothing", 'slug' => 'womens-clothing', 'sort_order' => 2],
                    ['name_ar' => 'ملابس أطفال',    'name_en' => "Children's Clothing", 'slug' => 'childrens-clothing', 'sort_order' => 3],
                    ['name_ar' => 'إكسسوارات',      'name_en' => 'Accessories',      'slug' => 'accessories',     'sort_order' => 4],
                ],
            ],
            [
                'name_ar'    => 'رياضة وترفيه',
                'name_en'    => 'Sports & Leisure',
                'slug'       => 'sports-leisure',
                'icon'       => '⚽',
                'sort_order' => 8,
                'is_free'    => false,
            ],
            [
                'name_ar'    => 'كتب ومجلات',
                'name_en'    => 'Books & Magazines',
                'slug'       => 'books-magazines',
                'icon'       => '📚',
                'sort_order' => 9,
                'is_free'    => false,
            ],
            [
                'name_ar'    => 'ألعاب وأطفال',
                'name_en'    => 'Toys & Kids',
                'slug'       => 'toys-kids',
                'icon'       => '🧸',
                'sort_order' => 10,
                'is_free'    => false,
            ],
            [
                'name_ar'     => 'حيوانات',
                'name_en'     => 'Animals',
                'slug'        => 'animals',
                'icon'        => '🐕',
                'sort_order'  => 11,
                'is_free'     => false,
                'prohibited_keywords' => ['قط', 'كلب', 'خنزير', 'قرد'],
            ],
            [
                'name_ar'    => 'مستلزمات شخصية',
                'name_en'    => 'Personal Items',
                'slug'       => 'personal-items',
                'icon'       => '🎒',
                'sort_order' => 12,
                'is_free'    => false,
            ],
            [
                'name_ar'    => 'أخرى',
                'name_en'    => 'Other',
                'slug'       => 'other',
                'icon'       => '📦',
                'sort_order' => 99,
                'is_free'    => false,
            ],
        ];

        foreach ($categories as $data) {
            $children = $data['children'] ?? [];
            unset($data['children']);

            $category = Category::firstOrCreate(
                ['slug' => $data['slug']],
                array_merge($data, [
                    'parent_id'     => null,
                    'is_active'     => true,
                    'prohibited_keywords' => $data['prohibited_keywords'] ?? null,
                ])
            );

            foreach ($children as $child) {
                Category::firstOrCreate(
                    ['slug' => $child['slug']],
                    array_merge($child, [
                        'parent_id'  => $category->id,
                        'is_active'  => true,
                        'is_free'    => $data['is_free'],
                    ])
                );
            }
        }
    }
}
