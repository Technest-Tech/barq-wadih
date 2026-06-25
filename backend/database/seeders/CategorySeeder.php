<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Artisan;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        // Publishing is FREE for every category — no upfront publish fee.
        $carsFees = ['publish_fee_individual' => 0.00, 'publish_fee_dealer' => 0.00];
        $otherFees = ['publish_fee_individual' => 0.00, 'publish_fee_dealer' => 0.00];

        // Flat commissions (SAR, VAT-inclusive): collected AFTER the sale.
        // Cars & Vehicles: 99 ر.س. Phones & all other paid sections: 10 ر.س. Free sections: 0.
        $carsDeferred = ['deferred_commission_individual' => 99.00, 'deferred_commission_dealer' => 99.00];
        $otherDeferred = ['deferred_commission_individual' => 10.00, 'deferred_commission_dealer' => 10.00];
        $phonesDeferred = $otherDeferred;

        $categories = [
            // ── 1. السيارات ────────────────────────────────────────────────────
            [
                'name_ar' => 'سيارات',
                'name_en' => 'Cars',
                'slug' => 'cars',
                'icon' => '🚗',
                'image' => 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=800&q=80',
                'sort_order' => 1,
                'is_free' => false,
                'fees' => $carsFees,
                'deferred' => $carsDeferred,
                'children' => [
                    ['name_ar' => 'سيارات للبيع',          'name_en' => 'Cars for Sale',          'slug' => 'cars-for-sale',       'icon' => '🛒', 'sort_order' => 1],
                    ['name_ar' => 'سيارات للإيجار',         'name_en' => 'Cars for Rent',          'slug' => 'cars-for-rent',       'icon' => '🔑', 'sort_order' => 2],
                    ['name_ar' => 'دراجات نارية',           'name_en' => 'Motorcycles',            'slug' => 'motorcycles',         'icon' => '🏍️', 'sort_order' => 3],
                    ['name_ar' => 'قطع غيار وملحقات',      'name_en' => 'Parts & Accessories',    'slug' => 'car-parts',           'icon' => '⚙️', 'sort_order' => 4],
                    ['name_ar' => 'شاحنات ومركبات ثقيلة',  'name_en' => 'Trucks & Heavy Vehicles', 'slug' => 'trucks',              'icon' => '🚛', 'sort_order' => 5],
                    ['name_ar' => 'معدات ثقيلة',            'name_en' => 'Heavy Equipment',        'slug' => 'heavy-equipment',     'icon' => '🏗️', 'sort_order' => 6],
                    ['name_ar' => 'لوحات مميزة',            'name_en' => 'Premium Plates',         'slug' => 'premium-plates',      'icon' => '🪪', 'sort_order' => 7],
                ],
            ],

            // ── 3. الأجهزة والإلكترونيات ────────────────────────────────────
            [
                'name_ar' => 'إلكترونيات وأجهزة',
                'name_en' => 'Electronics',
                'slug' => 'electronics',
                'icon' => '📱',
                'image' => 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=800&q=80',
                'sort_order' => 3,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'جوالات وأجهزة لوحية', 'name_en' => 'Phones & Tablets',      'slug' => 'phones-tablets',       'icon' => '📱', 'sort_order' => 1, 'deferred' => $phonesDeferred],
                    ['name_ar' => 'حاسبات ولابتوبات',    'name_en' => 'Computers & Laptops',   'slug' => 'computers',            'icon' => '💻', 'sort_order' => 2],
                    ['name_ar' => 'أجهزة منزلية',        'name_en' => 'Home Appliances',       'slug' => 'home-appliances',      'icon' => '🫙', 'sort_order' => 3],
                    ['name_ar' => 'ألعاب إلكترونية',     'name_en' => 'Gaming',                'slug' => 'gaming',               'icon' => '🎮', 'sort_order' => 4],
                    ['name_ar' => 'تلفزيونات وصوتيات',   'name_en' => 'TVs & Audio',           'slug' => 'tvs-audio',            'icon' => '📺', 'sort_order' => 5],
                    ['name_ar' => 'كاميرات وتصوير',      'name_en' => 'Cameras & Photography', 'slug' => 'cameras',              'icon' => '📷', 'sort_order' => 6],
                    ['name_ar' => 'أجهزة شبكات',         'name_en' => 'Networking',            'slug' => 'networking',           'icon' => '📡', 'sort_order' => 7],
                    ['name_ar' => 'أرقام مميزة',          'name_en' => 'Premium Phone Numbers', 'slug' => 'premium-numbers',      'icon' => '📞', 'sort_order' => 8],
                    ['name_ar' => 'حسابات واشتراكات',    'name_en' => 'Accounts & Subscriptions', 'slug' => 'accounts-subscriptions', 'icon' => '🔐', 'sort_order' => 9],
                    ['name_ar' => 'إلكترونيات أخرى',     'name_en' => 'Other Electronics',     'slug' => 'other-electronics',    'icon' => '🔌', 'sort_order' => 10],
                ],
            ],

            // ── 4. الحيوانات والمواشي ────────────────────────────────────────
            [
                'name_ar' => 'حيوانات ومواشي',
                'name_en' => 'Animals & Livestock',
                'slug' => 'animals',
                'icon' => '🐄',
                'image' => 'https://images.unsplash.com/photo-1450778869180-41d0601e046e?w=800&q=80',
                'sort_order' => 4,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'إبل',  'name_en' => 'Camels', 'slug' => 'camels', 'icon' => '🐪', 'sort_order' => 1],
                    ['name_ar' => 'غنم',  'name_en' => 'Sheep',  'slug' => 'sheep',  'icon' => '🐑', 'sort_order' => 2],
                    ['name_ar' => 'ماعز', 'name_en' => 'Goats',  'slug' => 'goats',  'icon' => '🐐', 'sort_order' => 3],
                    ['name_ar' => 'بقر',  'name_en' => 'Cattle', 'slug' => 'cattle', 'icon' => '🐄', 'sort_order' => 4],
                    ['name_ar' => 'خيول', 'name_en' => 'Horses', 'slug' => 'horses', 'icon' => '🐎', 'sort_order' => 5],
                    ['name_ar' => 'أرانب وسناجب', 'name_en' => 'Rabbits & Squirrels', 'slug' => 'rabbits-squirrels', 'icon' => '🐇', 'sort_order' => 6],
                    // طيور — تتفرع داخلياً (مستوى ثالث)
                    ['name_ar' => 'طيور', 'name_en' => 'Birds', 'slug' => 'birds', 'icon' => '🦜', 'sort_order' => 7, 'children' => [
                        ['name_ar' => 'حمام', 'name_en' => 'Pigeons',  'slug' => 'pigeons',  'icon' => '🕊️', 'sort_order' => 1],
                        ['name_ar' => 'دجاج', 'name_en' => 'Chickens', 'slug' => 'chickens', 'icon' => '🐔', 'sort_order' => 2],
                        ['name_ar' => 'بط',   'name_en' => 'Ducks',    'slug' => 'ducks',    'icon' => '🦆', 'sort_order' => 3],
                    ]],
                    ['name_ar' => 'أسماك زينة', 'name_en' => 'Ornamental Fish', 'slug' => 'ornamental-fish', 'icon' => '🐠', 'sort_order' => 8],
                ],
            ],

            // ── 5. الأثاث ─────────────────────────────────────────────────────
            [
                'name_ar' => 'أثاث ومفروشات',
                'name_en' => 'Furniture',
                'slug' => 'furniture',
                'icon' => '🛋️',
                'image' => 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800&q=80',
                'sort_order' => 5,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'غرف نوم',        'name_en' => 'Bedrooms',          'slug' => 'bedrooms',         'icon' => '🛏️', 'sort_order' => 1],
                    ['name_ar' => 'مجالس وصالات',   'name_en' => 'Living Rooms',      'slug' => 'living-rooms',     'icon' => '🛋️', 'sort_order' => 2],
                    ['name_ar' => 'مطابخ',           'name_en' => 'Kitchens',          'slug' => 'kitchens',         'icon' => '🍳', 'sort_order' => 3],
                    ['name_ar' => 'أثاث مكتبي',     'name_en' => 'Office Furniture',  'slug' => 'office-furniture', 'icon' => '🪑', 'sort_order' => 4],
                    ['name_ar' => 'أثاث خارجي',     'name_en' => 'Outdoor Furniture', 'slug' => 'outdoor-furniture', 'icon' => '⛱️', 'sort_order' => 5],
                    ['name_ar' => 'أسرة ومراتب',    'name_en' => 'Beds & Mattresses', 'slug' => 'beds-mattresses',  'icon' => '🛏️', 'sort_order' => 6],
                    ['name_ar' => 'خزائن ودواليب',  'name_en' => 'Wardrobes',         'slug' => 'wardrobes',        'icon' => '🗄️', 'sort_order' => 7],
                    ['name_ar' => 'طاولات وكراسي',  'name_en' => 'Tables & Chairs',   'slug' => 'tables-chairs',    'icon' => '🪑', 'sort_order' => 8],
                    ['name_ar' => 'تحف وديكور',     'name_en' => 'Decor & Antiques',  'slug' => 'decor',            'icon' => '🖼️', 'sort_order' => 9],
                    ['name_ar' => 'أدوات منزلية',   'name_en' => 'Home Tools',        'slug' => 'home-tools',       'icon' => '🪛', 'sort_order' => 10],
                ],
            ],

            // ── 6. الوظائف ────────────────────────────────────────────────────
            [
                'name_ar' => 'وظائف',
                'name_en' => 'Jobs',
                'slug' => 'jobs',
                'icon' => '💼',
                'image' => 'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=800&q=80',
                'sort_order' => 6,
                'is_free' => true,
                'children' => [
                    ['name_ar' => 'إدارة وموارد بشرية', 'name_en' => 'Admin & HR',             'slug' => 'admin-hr',          'icon' => '🧑‍💼', 'sort_order' => 1],
                    ['name_ar' => 'تقنية وتصميم',       'name_en' => 'Tech & Design',           'slug' => 'tech-design',       'icon' => '💻', 'sort_order' => 2],
                    ['name_ar' => 'تسويق ومبيعات',      'name_en' => 'Marketing & Sales',       'slug' => 'marketing-sales',   'icon' => '📊', 'sort_order' => 3],
                    ['name_ar' => 'طب وتمريض',          'name_en' => 'Medical & Nursing',        'slug' => 'medical',           'icon' => '🏥', 'sort_order' => 4],
                    ['name_ar' => 'تعليم وتدريب',       'name_en' => 'Education & Training',     'slug' => 'education-jobs',    'icon' => '🎓', 'sort_order' => 5],
                    ['name_ar' => 'عمارة وبناء',        'name_en' => 'Construction',             'slug' => 'construction-jobs', 'icon' => '🏗️', 'sort_order' => 6],
                    ['name_ar' => 'عمالة منزلية',       'name_en' => 'Domestic Work',            'slug' => 'domestic-work',     'icon' => '🏠', 'sort_order' => 7],
                    ['name_ar' => 'مطاعم وضيافة',       'name_en' => 'Restaurants & Hospitality', 'slug' => 'hospitality',       'icon' => '🍽️', 'sort_order' => 8],
                    ['name_ar' => 'أمن وسلامة',         'name_en' => 'Security & Safety',        'slug' => 'security-safety',   'icon' => '🛡️', 'sort_order' => 9],
                    ['name_ar' => 'زراعة ورعي',         'name_en' => 'Agriculture',              'slug' => 'agriculture-jobs',  'icon' => '🌾', 'sort_order' => 10],
                    ['name_ar' => 'أزياء وتجميل',       'name_en' => 'Beauty & Fashion',         'slug' => 'beauty-jobs',       'icon' => '💄', 'sort_order' => 11],
                    ['name_ar' => 'محاسبة ومالية',      'name_en' => 'Accounting & Finance',     'slug' => 'accounting-jobs',   'icon' => '💰', 'sort_order' => 12],
                    ['name_ar' => 'سياحة وفندقة',       'name_en' => 'Tourism & Hotels',         'slug' => 'tourism-jobs',      'icon' => '✈️', 'sort_order' => 13],
                    ['name_ar' => 'قانون وشريعة',       'name_en' => 'Legal',                    'slug' => 'legal-jobs',        'icon' => '⚖️', 'sort_order' => 14],
                ],
            ],

            // ── 7. الخدمات ────────────────────────────────────────────────────
            [
                'name_ar' => 'خدمات',
                'name_en' => 'Services',
                'slug' => 'services',
                'icon' => '🔧',
                'image' => 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&q=80',
                'sort_order' => 7,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'خدمات منزلية',    'name_en' => 'Home Services',         'slug' => 'home-services',     'icon' => '🔨', 'sort_order' => 1],
                    ['name_ar' => 'نقل العفش',        'name_en' => 'Moving Services',       'slug' => 'moving-services',   'icon' => '🚚', 'sort_order' => 2],
                    ['name_ar' => 'نظافة',            'name_en' => 'Cleaning',              'slug' => 'cleaning-services', 'icon' => '🧹', 'sort_order' => 3],
                    ['name_ar' => 'خدمات قانونية',   'name_en' => 'Legal Services',        'slug' => 'legal-services',    'icon' => '⚖️', 'sort_order' => 4],
                    ['name_ar' => 'محاسبة ومالية',   'name_en' => 'Accounting & Finance',  'slug' => 'accounting-services', 'icon' => '📊', 'sort_order' => 5],
                    ['name_ar' => 'تعقيب ومعاملات',  'name_en' => 'Gov. Transactions',     'slug' => 'government-services', 'icon' => '🏛️', 'sort_order' => 6],
                    ['name_ar' => 'خدمات توصيل',     'name_en' => 'Delivery Services',     'slug' => 'delivery-services', 'icon' => '📦', 'sort_order' => 7],
                    ['name_ar' => 'مقاولات',          'name_en' => 'Contracting',           'slug' => 'contracting-services', 'icon' => '🏗️', 'sort_order' => 8],
                    ['name_ar' => 'خدمات أخرى',      'name_en' => 'Other Services',        'slug' => 'other-services',    'icon' => '🛠️', 'sort_order' => 9],
                ],
            ],

            // ── 8. أزياء ومستلزمات شخصية ────────────────────────────────────
            [
                'name_ar' => 'أزياء ومستلزمات شخصية',
                'name_en' => 'Fashion & Personal Items',
                'slug' => 'fashion',
                'icon' => '👗',
                'image' => 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=800&q=80',
                'sort_order' => 8,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'ساعات',           'name_en' => 'Watches',            'slug' => 'watches',         'icon' => '⌚', 'sort_order' => 1],
                    ['name_ar' => 'عطور وبخور',      'name_en' => 'Perfumes & Incense', 'slug' => 'perfumes',        'icon' => '🪔', 'sort_order' => 2],
                    ['name_ar' => 'نظارات',          'name_en' => 'Eyeglasses',         'slug' => 'eyeglasses',      'icon' => '👓', 'sort_order' => 3],
                    ['name_ar' => 'أزياء رجالية',   'name_en' => "Men's Fashion",      'slug' => 'mens-fashion',    'icon' => '👔', 'sort_order' => 4],
                    ['name_ar' => 'أزياء نسائية',   'name_en' => "Women's Fashion",    'slug' => 'womens-fashion',  'icon' => '👗', 'sort_order' => 5],
                    ['name_ar' => 'ملابس أطفال',    'name_en' => "Kids' Clothing",     'slug' => 'kids-fashion',    'icon' => '👶', 'sort_order' => 6],
                    ['name_ar' => 'حقائب وشنط',     'name_en' => 'Bags & Handbags',    'slug' => 'bags',            'icon' => '👜', 'sort_order' => 7],
                    ['name_ar' => 'مستلزمات رياضية', 'name_en' => 'Sports Items',       'slug' => 'sports-items',    'icon' => '⚽', 'sort_order' => 8],
                    ['name_ar' => 'الصحة والجمال',  'name_en' => 'Health & Beauty',    'slug' => 'health-beauty',   'icon' => '💄', 'sort_order' => 9],
                    ['name_ar' => 'هدايا وتذكارات', 'name_en' => 'Gifts & Souvenirs',  'slug' => 'gifts',           'icon' => '🎁', 'sort_order' => 10],
                ],
            ],

            // ── 9. الألعاب والترفيه ──────────────────────────────────────────
            [
                'name_ar' => 'ألعاب وترفيه',
                'name_en' => 'Games & Entertainment',
                'slug' => 'games-entertainment',
                'icon' => '🎮',
                'sort_order' => 9,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'ألعاب فيديو',    'name_en' => 'Video Games',         'slug' => 'video-games',     'icon' => '🕹️', 'sort_order' => 1],
                    ['name_ar' => 'ألعاب أطفال',    'name_en' => "Children's Toys",     'slug' => 'toys',            'icon' => '🧸', 'sort_order' => 2],
                    ['name_ar' => 'رياضة ولياقة',   'name_en' => 'Sports & Fitness',    'slug' => 'sports-fitness',  'icon' => '🏋️', 'sort_order' => 3],
                    ['name_ar' => 'موسيقى وآلات',   'name_en' => 'Music & Instruments', 'slug' => 'music',           'icon' => '🎸', 'sort_order' => 4],
                    ['name_ar' => 'ترفيه أخرى',     'name_en' => 'Other Entertainment', 'slug' => 'other-entertainment', 'icon' => '🎭', 'sort_order' => 5],
                ],
            ],

            // ── 10. نوادر وتراثيات ───────────────────────────────────────────
            [
                'name_ar' => 'نوادر وتراثيات',
                'name_en' => 'Antiques & Heritage',
                'slug' => 'antiques',
                'icon' => '🏺',
                'sort_order' => 10,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'عملات وطوابع',    'name_en' => 'Coins & Stamps',      'slug' => 'coins-stamps',    'icon' => '🪙', 'sort_order' => 1],
                    ['name_ar' => 'أسلحة قديمة',     'name_en' => 'Antique Weapons',     'slug' => 'antique-weapons', 'icon' => '⚔️', 'sort_order' => 2],
                    ['name_ar' => 'تراث وأثريات',    'name_en' => 'Heritage Items',      'slug' => 'heritage',        'icon' => '🏺', 'sort_order' => 3],
                ],
            ],

            // ── 11. كتب وفنون ─────────────────────────────────────────────────
            [
                'name_ar' => 'كتب وفنون',
                'name_en' => 'Books & Arts',
                'slug' => 'books-arts',
                'icon' => '📚',
                'sort_order' => 11,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'كتب ومجلات',   'name_en' => 'Books & Magazines', 'slug' => 'books',         'icon' => '📖', 'sort_order' => 1],
                    ['name_ar' => 'لوحات وفنون',  'name_en' => 'Paintings & Arts',  'slug' => 'arts',          'icon' => '🎨', 'sort_order' => 2],
                    ['name_ar' => 'خط وزخرفة',    'name_en' => 'Calligraphy',       'slug' => 'calligraphy',   'icon' => '✍️', 'sort_order' => 3],
                ],
            ],

            // ── 12. صيد ورحلات ───────────────────────────────────────────────
            [
                'name_ar' => 'صيد ورحلات',
                'name_en' => 'Hunting & Trips',
                'slug' => 'hunting-trips',
                'icon' => '🎣',
                'sort_order' => 12,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'صيد أسماك',      'name_en' => 'Fishing',              'slug' => 'fishing',         'icon' => '🎣', 'sort_order' => 1],
                    ['name_ar' => 'صيد طيور وبر',   'name_en' => 'Hunting',              'slug' => 'hunting',         'icon' => '🦅', 'sort_order' => 2],
                    ['name_ar' => 'معدات صيد ورحلات', 'name_en' => 'Hunting & Trip Gear', 'slug' => 'outdoor-gear',    'icon' => '⛺', 'sort_order' => 3],
                ],
            ],

            // ── 13. أطعمة ومشروبات ──────────────────────────────────────────
            [
                'name_ar' => 'أطعمة ومشروبات',
                'name_en' => 'Food & Beverages',
                'slug' => 'food-beverages',
                'icon' => '🍽️',
                'sort_order' => 13,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'وجبات ومأكولات', 'name_en' => 'Meals & Food',        'slug' => 'meals',           'icon' => '🍱', 'sort_order' => 1],
                    ['name_ar' => 'حلويات وكيك',    'name_en' => 'Sweets & Cakes',      'slug' => 'sweets',          'icon' => '🎂', 'sort_order' => 2],
                    ['name_ar' => 'مشروبات',         'name_en' => 'Beverages',           'slug' => 'beverages',       'icon' => '☕', 'sort_order' => 3],
                    ['name_ar' => 'منتجات عضوية',   'name_en' => 'Organic Products',    'slug' => 'organic',         'icon' => '🥦', 'sort_order' => 4],
                ],
            ],

            // ── 14. زراعة وحدائق ─────────────────────────────────────────────
            [
                'name_ar' => 'زراعة وحدائق',
                'name_en' => 'Agriculture & Gardens',
                'slug' => 'agriculture-gardens',
                'icon' => '🌱',
                'sort_order' => 14,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'نباتات وشجيرات', 'name_en' => 'Plants & Shrubs',     'slug' => 'plants',          'icon' => '🌿', 'sort_order' => 1],
                    ['name_ar' => 'بذور وشتلات',    'name_en' => 'Seeds & Seedlings',   'slug' => 'seeds',           'icon' => '🌱', 'sort_order' => 2],
                    ['name_ar' => 'معدات زراعية',   'name_en' => 'Agricultural Tools',  'slug' => 'agri-tools',      'icon' => '🚜', 'sort_order' => 3],
                    ['name_ar' => 'أشجار ونخيل',    'name_en' => 'Trees & Palms',       'slug' => 'trees',           'icon' => '🌴', 'sort_order' => 4],
                ],
            ],

            // ── 15. حفلات ومناسبات ───────────────────────────────────────────
            [
                'name_ar' => 'حفلات ومناسبات',
                'name_en' => 'Events & Occasions',
                'slug' => 'events-occasions',
                'icon' => '🎉',
                'sort_order' => 15,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'زفاف وأعراس',    'name_en' => 'Weddings',            'slug' => 'weddings',        'icon' => '💍', 'sort_order' => 1],
                    ['name_ar' => 'تنظيم فعاليات', 'name_en' => 'Event Planning',      'slug' => 'event-planning',  'icon' => '🎊', 'sort_order' => 2],
                    ['name_ar' => 'مستلزمات حفلات', 'name_en' => 'Party Supplies',      'slug' => 'party-supplies',  'icon' => '🎈', 'sort_order' => 3],
                    ['name_ar' => 'دي جي وفرق',     'name_en' => 'DJs & Bands',         'slug' => 'dj-bands',        'icon' => '🎵', 'sort_order' => 4],
                ],
            ],

            // ── 16. سفر وسياحة ───────────────────────────────────────────────
            [
                'name_ar' => 'سفر وسياحة',
                'name_en' => 'Travel & Tourism',
                'slug' => 'travel-tourism',
                'icon' => '✈️',
                'sort_order' => 16,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'شقق مخدومة',  'name_en' => 'Serviced Apartments', 'slug' => 'serviced-apartments', 'icon' => '🏨', 'sort_order' => 1],
                    ['name_ar' => 'شاليهات',      'name_en' => 'Chalets',             'slug' => 'travel-chalets',    'icon' => '🏕️', 'sort_order' => 2],
                    ['name_ar' => 'شريك سكن',     'name_en' => 'Roommate',            'slug' => 'roommate',          'icon' => '🤝', 'sort_order' => 3],
                    ['name_ar' => 'رحلات وبرامج', 'name_en' => 'Trips & Packages',    'slug' => 'travel-packages',   'icon' => '🗺️', 'sort_order' => 4],
                    ['name_ar' => 'تذاكر طيران',  'name_en' => 'Flight Tickets',      'slug' => 'flight-tickets',    'icon' => '🎫', 'sort_order' => 5],
                ],
            ],

            // ── 17. تعليم وتدريب ──────────────────────────────────────────────
            [
                'name_ar' => 'تعليم وتدريب',
                'name_en' => 'Education & Training',
                'slug' => 'education-training',
                'icon' => '🎓',
                'sort_order' => 17,
                'is_free' => true,
                'children' => [
                    ['name_ar' => 'دروس خصوصية',          'name_en' => 'Private Lessons',     'slug' => 'private-lessons',    'icon' => '📝', 'sort_order' => 1],
                    ['name_ar' => 'دورات تدريبية',         'name_en' => 'Training Courses',    'slug' => 'training-courses',   'icon' => '📋', 'sort_order' => 2],
                    ['name_ar' => 'تعليم قيادة',           'name_en' => 'Driving Lessons',     'slug' => 'driving-lessons',    'icon' => '🚗', 'sort_order' => 3],
                    ['name_ar' => 'تدريب رياضي',           'name_en' => 'Sports Training',     'slug' => 'sports-training',    'icon' => '🏋️', 'sort_order' => 4],
                    ['name_ar' => 'تعليم أسهم وعملات',    'name_en' => 'Stocks & Trading',    'slug' => 'stocks-trading',     'icon' => '📈', 'sort_order' => 5],
                    ['name_ar' => 'تدريب ألعاب إلكترونية', 'name_en' => 'Gaming Coaching',     'slug' => 'gaming-coaching',    'icon' => '🎮', 'sort_order' => 6],
                ],
            ],

            // ── 18. برمجة وتصاميم ─────────────────────────────────────────────
            [
                'name_ar' => 'برمجة وتصاميم',
                'name_en' => 'Programming & Design',
                'slug' => 'programming-design',
                'icon' => '💻',
                'sort_order' => 18,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'تطوير مواقع',       'name_en' => 'Web Development',      'slug' => 'web-dev',         'icon' => '🌐', 'sort_order' => 1],
                    ['name_ar' => 'تطبيقات موبايل',    'name_en' => 'Mobile Apps',          'slug' => 'mobile-apps',     'icon' => '📱', 'sort_order' => 2],
                    ['name_ar' => 'تصميم جرافيك',      'name_en' => 'Graphic Design',       'slug' => 'graphic-design',  'icon' => '🎨', 'sort_order' => 3],
                    ['name_ar' => 'إدارة سوشيال ميديا', 'name_en' => 'Social Media Mgmt',   'slug' => 'social-media',    'icon' => '📲', 'sort_order' => 4],
                    ['name_ar' => 'كتابة محتوى',       'name_en' => 'Content Writing',      'slug' => 'content-writing', 'icon' => '✍️', 'sort_order' => 5],
                    ['name_ar' => 'ذكاء اصطناعي',      'name_en' => 'AI & Automation',      'slug' => 'ai-automation',   'icon' => '🤖', 'sort_order' => 6],
                ],
            ],

            // ── 19. مشاريع واستثمارات ────────────────────────────────────────
            [
                'name_ar' => 'مشاريع واستثمارات',
                'name_en' => 'Projects & Investments',
                'slug' => 'investments',
                'icon' => '💰',
                'sort_order' => 19,
                'is_free' => false,
                'children' => [
                    ['name_ar' => 'مشاريع للبيع',    'name_en' => 'Projects for Sale',    'slug' => 'projects-for-sale', 'icon' => '🏪', 'sort_order' => 1],
                    ['name_ar' => 'شراكات وتمويل',   'name_en' => 'Partnerships',         'slug' => 'partnerships',     'icon' => '🤝', 'sort_order' => 2],
                    ['name_ar' => 'امتيازات تجارية', 'name_en' => 'Franchises',           'slug' => 'franchises',       'icon' => '⭐', 'sort_order' => 3],
                ],
            ],

            // ── 20. أخرى ─────────────────────────────────────────────────────
            [
                'name_ar' => 'أخرى',
                'name_en' => 'Other',
                'slug' => 'other',
                'icon' => '📦',
                'sort_order' => 99,
                'is_free' => false,
            ],
        ];

        foreach ($categories as $data) {
            $this->upsertCategory($data, null, $otherFees, $otherDeferred, $data['is_free'] ?? false);
        }

        // Point main categories at the self-hosted gradient-tile SVG icons so a
        // fresh seed gets the modern icons without a manual step.
        Artisan::call('categories:set-icons');
    }

    /**
     * Recursively upsert a category node and its descendants. Supports 3+ levels
     * (e.g. حيوانات → طيور → حمام/دجاج/بط). Each child inherits the parent's fees,
     * deferred commission and is_free flag unless it overrides them.
     */
    private function upsertCategory(array $data, ?int $parentId, array $fees, array $deferred, bool $isFree): void
    {
        $children = $data['children'] ?? [];
        $fees = $data['fees'] ?? $fees;
        $deferred = $data['deferred'] ?? $deferred;
        $isFree = $data['is_free'] ?? $isFree;
        unset($data['children'], $data['fees'], $data['deferred'], $data['is_free']);

        $attrs = array_merge($data, [
            'parent_id' => $parentId,
            'is_active' => $data['is_active'] ?? true,
            'is_free' => $isFree,
            'image' => $data['image'] ?? null,
            'prohibited_keywords' => $data['prohibited_keywords'] ?? null,
            'commission_rate' => $data['commission_rate'] ?? null,
            'commission_trigger' => 'after_sale',
            'publish_fee_individual' => $fees['publish_fee_individual'],
            'publish_fee_dealer' => $fees['publish_fee_dealer'],
            'fee_deductible_from_commission' => true,
            'deferred_commission_individual' => $deferred['deferred_commission_individual'] ?? 0,
            'deferred_commission_dealer' => $deferred['deferred_commission_dealer'] ?? 0,
        ]);

        $category = Category::updateOrCreate(['slug' => $data['slug']], $attrs);

        foreach ($children as $child) {
            $this->upsertCategory($child, $category->id, $fees, $deferred, $isFree);
        }
    }
}
