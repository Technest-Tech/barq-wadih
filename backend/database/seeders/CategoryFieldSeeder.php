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
        // Only "سيارات للبيع" (cars-for-sale) has extra inputs. All four are
        // required free-text fields. Every other category collects just
        // title/description/price/images.
        $carsForSale = Category::where('slug', 'cars-for-sale')->first();
        if (! $carsForSale) {
            return;
        }

        $fields = [
            [
                'field_key'      => 'car_name',
                'label_ar'       => 'النوع',
                'label_en'       => 'Type',
                'field_type'     => FieldType::Text->value,
                'is_required'    => true,
                'is_filterable'  => true,
                'sort_order'     => 1,
                'placeholder_ar' => 'مثال: كامري، لاندكروزر',
                'placeholder_en' => 'e.g. Camry, Land Cruiser',
            ],
            [
                'field_key'      => 'model_year',
                'label_ar'       => 'الموديل (سنة الصنع)',
                'label_en'       => 'Model (Year)',
                'field_type'     => FieldType::Text->value,
                'is_required'    => true,
                'is_filterable'  => true,
                'sort_order'     => 2,
                'placeholder_ar' => 'مثال: 2020',
                'placeholder_en' => 'e.g. 2020',
            ],
            [
                'field_key'      => 'mileage',
                'label_ar'       => 'الممشى',
                'label_en'       => 'Mileage',
                'field_type'     => FieldType::Text->value,
                'is_required'    => true,
                'is_filterable'  => true,
                'sort_order'     => 3,
                'placeholder_ar' => 'مثال: 80,000 كم',
                'placeholder_en' => 'e.g. 80,000 km',
            ],
            [
                'field_key'      => 'color',
                'label_ar'       => 'اللون',
                'label_en'       => 'Color',
                'field_type'     => FieldType::Text->value,
                'is_required'    => true,
                'is_filterable'  => true,
                'sort_order'     => 4,
                'placeholder_ar' => 'مثال: أبيض',
                'placeholder_en' => 'e.g. White',
            ],
        ];

        foreach ($fields as $field) {
            CategoryField::updateOrCreate(
                ['category_id' => $carsForSale->id, 'field_key' => $field['field_key']],
                array_merge($field, ['category_id' => $carsForSale->id])
            );
        }
    }
}
