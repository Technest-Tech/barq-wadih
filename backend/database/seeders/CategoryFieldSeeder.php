<?php

namespace Database\Seeders;

use App\Enums\FieldType;
use App\Models\Category;
use App\Models\CategoryField;
use Illuminate\Database\Seeder;

class CategoryFieldSeeder extends Seeder
{
    public function run(): void
    {
        // ── Cars fields ──────────────────────────────────────────────────────
        $carsForSale = Category::where('slug', 'cars-for-sale')->first();
        if ($carsForSale) {
            $fields = [
                [
                    'field_key'       => 'car_make',
                    'label_ar'        => 'الشركة المصنعة',
                    'label_en'        => 'Car Make',
                    'field_type'      => FieldType::Select->value,
                    'is_required'     => true,
                    'is_filterable'   => true,
                    'sort_order'      => 1,
                    'options'         => json_encode([
                        ['value' => 'toyota',   'label_ar' => 'تويوتا',    'label_en' => 'Toyota'],
                        ['value' => 'nissan',   'label_ar' => 'نيسان',     'label_en' => 'Nissan'],
                        ['value' => 'hyundai',  'label_ar' => 'هيونداي',   'label_en' => 'Hyundai'],
                        ['value' => 'kia',      'label_ar' => 'كيا',       'label_en' => 'Kia'],
                        ['value' => 'ford',     'label_ar' => 'فورد',      'label_en' => 'Ford'],
                        ['value' => 'gmc',      'label_ar' => 'جي إم سي',  'label_en' => 'GMC'],
                        ['value' => 'chevrolet','label_ar' => 'شيفروليه',  'label_en' => 'Chevrolet'],
                        ['value' => 'bmw',      'label_ar' => 'بي إم دبليو','label_en' => 'BMW'],
                        ['value' => 'mercedes', 'label_ar' => 'مرسيدس',    'label_en' => 'Mercedes-Benz'],
                        ['value' => 'honda',    'label_ar' => 'هوندا',     'label_en' => 'Honda'],
                        ['value' => 'mitsubishi','label_ar' => 'ميتسوبيشي','label_en' => 'Mitsubishi'],
                        ['value' => 'lexus',    'label_ar' => 'لكزس',      'label_en' => 'Lexus'],
                        ['value' => 'land_rover','label_ar' => 'لاند روفر','label_en' => 'Land Rover'],
                        ['value' => 'jeep',     'label_ar' => 'جيب',       'label_en' => 'Jeep'],
                        ['value' => 'other',    'label_ar' => 'أخرى',      'label_en' => 'Other'],
                    ]),
                ],
                [
                    'field_key'       => 'car_model',
                    'label_ar'        => 'الموديل',
                    'label_en'        => 'Model',
                    'field_type'      => FieldType::Text->value,
                    'is_required'     => true,
                    'is_filterable'   => false,
                    'sort_order'      => 2,
                    'placeholder_ar'  => 'مثال: كامري، باترول، سوناتا...',
                    'placeholder_en'  => 'e.g. Camry, Patrol, Sonata...',
                ],
                [
                    'field_key'       => 'year',
                    'label_ar'        => 'سنة الصنع',
                    'label_en'        => 'Year',
                    'field_type'      => FieldType::Year->value,
                    'is_required'     => true,
                    'is_filterable'   => true,
                    'sort_order'      => 3,
                    'validation_rules'=> json_encode(['min' => 1990, 'max' => 2026]),
                ],
                [
                    'field_key'       => 'mileage',
                    'label_ar'        => 'عداد الكيلومترات',
                    'label_en'        => 'Mileage (km)',
                    'field_type'      => FieldType::Number->value,
                    'is_required'     => true,
                    'is_filterable'   => true,
                    'sort_order'      => 4,
                    'placeholder_ar'  => 'الكيلومترات',
                    'placeholder_en'  => 'Kilometers',
                    'validation_rules'=> json_encode(['min' => 0, 'max' => 9999999]),
                ],
                [
                    'field_key'       => 'fuel_type',
                    'label_ar'        => 'نوع الوقود',
                    'label_en'        => 'Fuel Type',
                    'field_type'      => FieldType::Select->value,
                    'is_required'     => true,
                    'is_filterable'   => true,
                    'sort_order'      => 5,
                    'options'         => json_encode([
                        ['value' => 'petrol',   'label_ar' => 'بنزين',    'label_en' => 'Petrol'],
                        ['value' => 'diesel',   'label_ar' => 'ديزل',     'label_en' => 'Diesel'],
                        ['value' => 'hybrid',   'label_ar' => 'هجين',     'label_en' => 'Hybrid'],
                        ['value' => 'electric', 'label_ar' => 'كهربائي',  'label_en' => 'Electric'],
                    ]),
                ],
                [
                    'field_key'       => 'transmission',
                    'label_ar'        => 'ناقل الحركة',
                    'label_en'        => 'Transmission',
                    'field_type'      => FieldType::Select->value,
                    'is_required'     => true,
                    'is_filterable'   => true,
                    'sort_order'      => 6,
                    'options'         => json_encode([
                        ['value' => 'automatic', 'label_ar' => 'أوتوماتيك', 'label_en' => 'Automatic'],
                        ['value' => 'manual',    'label_ar' => 'عادي',      'label_en' => 'Manual'],
                    ]),
                ],
                [
                    'field_key'       => 'color',
                    'label_ar'        => 'اللون',
                    'label_en'        => 'Color',
                    'field_type'      => FieldType::Select->value,
                    'is_required'     => false,
                    'is_filterable'   => true,
                    'sort_order'      => 7,
                    'options'         => json_encode([
                        ['value' => 'white',  'label_ar' => 'أبيض',  'label_en' => 'White'],
                        ['value' => 'black',  'label_ar' => 'أسود',  'label_en' => 'Black'],
                        ['value' => 'silver', 'label_ar' => 'فضي',   'label_en' => 'Silver'],
                        ['value' => 'gray',   'label_ar' => 'رمادي', 'label_en' => 'Gray'],
                        ['value' => 'red',    'label_ar' => 'أحمر',  'label_en' => 'Red'],
                        ['value' => 'blue',   'label_ar' => 'أزرق',  'label_en' => 'Blue'],
                        ['value' => 'other',  'label_ar' => 'أخرى',  'label_en' => 'Other'],
                    ]),
                ],
            ];

            foreach ($fields as $field) {
                CategoryField::firstOrCreate(
                    ['category_id' => $carsForSale->id, 'field_key' => $field['field_key']],
                    array_merge($field, ['category_id' => $carsForSale->id])
                );
            }
        }

        // ── Electronics fields ───────────────────────────────────────────────
        $phones = Category::where('slug', 'phones-tablets')->first();
        if ($phones) {
            $phoneFields = [
                [
                    'field_key'    => 'brand',
                    'label_ar'     => 'الشركة',
                    'label_en'     => 'Brand',
                    'field_type'   => FieldType::Select->value,
                    'is_required'  => true,
                    'is_filterable'=> true,
                    'sort_order'   => 1,
                    'options'      => json_encode([
                        ['value' => 'apple',   'label_ar' => 'آبل',     'label_en' => 'Apple'],
                        ['value' => 'samsung', 'label_ar' => 'سامسونج', 'label_en' => 'Samsung'],
                        ['value' => 'huawei',  'label_ar' => 'هواوي',   'label_en' => 'Huawei'],
                        ['value' => 'xiaomi',  'label_ar' => 'شاومي',   'label_en' => 'Xiaomi'],
                        ['value' => 'oppo',    'label_ar' => 'أوبو',    'label_en' => 'Oppo'],
                        ['value' => 'other',   'label_ar' => 'أخرى',    'label_en' => 'Other'],
                    ]),
                ],
                [
                    'field_key'    => 'condition',
                    'label_ar'     => 'الحالة',
                    'label_en'     => 'Condition',
                    'field_type'   => FieldType::Select->value,
                    'is_required'  => true,
                    'is_filterable'=> true,
                    'sort_order'   => 2,
                    'options'      => json_encode([
                        ['value' => 'new',        'label_ar' => 'جديد',        'label_en' => 'New'],
                        ['value' => 'like_new',   'label_ar' => 'مثل الجديد',  'label_en' => 'Like New'],
                        ['value' => 'good',       'label_ar' => 'جيد',         'label_en' => 'Good'],
                        ['value' => 'acceptable', 'label_ar' => 'مقبول',       'label_en' => 'Acceptable'],
                    ]),
                ],
            ];

            foreach ($phoneFields as $field) {
                CategoryField::firstOrCreate(
                    ['category_id' => $phones->id, 'field_key' => $field['field_key']],
                    array_merge($field, ['category_id' => $phones->id])
                );
            }
        }
    }
}
