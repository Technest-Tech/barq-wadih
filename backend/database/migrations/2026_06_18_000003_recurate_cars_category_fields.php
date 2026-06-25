<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Re-curate the dynamic category fields: the only category with extra inputs is
 * "سيارات للبيع" (cars-for-sale), which gets exactly four required text fields:
 *   النوع (car name), الموديل (سنة الصنع), الممشى, اللون.
 * Every other category collects just title/description/price/images.
 *
 * This wipes the old car fields (car_make, car_model, year, mileage, fuel_type,
 * transmission, color) and any other category fields; the cascade on
 * ad_field_values drops their now-orphaned values.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Clear all existing dynamic fields (and their ad values, via FK cascade).
        DB::table('category_fields')->delete();

        $catId = DB::table('categories')->where('slug', 'cars-for-sale')->value('id');
        if (! $catId) {
            return;
        }

        $now = now();
        DB::table('category_fields')->insert([
            [
                'category_id'      => $catId,
                'field_key'        => 'car_name',
                'label_ar'         => 'النوع',
                'label_en'         => 'Type',
                'field_type'       => 'text',
                'options'          => null,
                'is_required'      => true,
                'is_filterable'    => true,
                'sort_order'       => 1,
                'placeholder_ar'   => 'مثال: كامري، لاندكروزر',
                'placeholder_en'   => 'e.g. Camry, Land Cruiser',
                'validation_rules' => null,
                'created_at'       => $now,
                'updated_at'       => $now,
            ],
            [
                'category_id'      => $catId,
                'field_key'        => 'model_year',
                'label_ar'         => 'الموديل (سنة الصنع)',
                'label_en'         => 'Model (Year)',
                'field_type'       => 'text',
                'options'          => null,
                'is_required'      => true,
                'is_filterable'    => true,
                'sort_order'       => 2,
                'placeholder_ar'   => 'مثال: 2020',
                'placeholder_en'   => 'e.g. 2020',
                'validation_rules' => null,
                'created_at'       => $now,
                'updated_at'       => $now,
            ],
            [
                'category_id'      => $catId,
                'field_key'        => 'mileage',
                'label_ar'         => 'الممشى',
                'label_en'         => 'Mileage',
                'field_type'       => 'text',
                'options'          => null,
                'is_required'      => true,
                'is_filterable'    => true,
                'sort_order'       => 3,
                'placeholder_ar'   => 'مثال: 80,000 كم',
                'placeholder_en'   => 'e.g. 80,000 km',
                'validation_rules' => null,
                'created_at'       => $now,
                'updated_at'       => $now,
            ],
            [
                'category_id'      => $catId,
                'field_key'        => 'color',
                'label_ar'         => 'اللون',
                'label_en'         => 'Color',
                'field_type'       => 'text',
                'options'          => null,
                'is_required'      => true,
                'is_filterable'    => true,
                'sort_order'       => 4,
                'placeholder_ar'   => 'مثال: أبيض',
                'placeholder_en'   => 'e.g. White',
                'validation_rules' => null,
                'created_at'       => $now,
                'updated_at'       => $now,
            ],
        ]);
    }

    public function down(): void
    {
        // Irreversible data re-curation; nothing to restore.
    }
};
