<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the new location depth (district + map pin) and two privacy/display
 * flags requested by the client:
 *
 *   - district_id           — FK; nullable so existing ads keep working
 *   - district_name_free    — fallback when no seeded district matches
 *   - latitude / longitude  — map-pinned exact coords, distinct from city center
 *   - show_phone_publicly   — gate contact_phone visibility on the public detail page
 *   - price_hidden          — "اتصل للسعر" (kept distinct from is_free / مجاني)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->foreignId('district_id')->nullable()->after('city_id')->constrained()->nullOnDelete();
            $table->string('district_name_free', 120)->nullable()->after('district_id');
            $table->decimal('latitude', 10, 7)->nullable()->after('district_name_free');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->boolean('show_phone_publicly')->default(true)->after('contact_whatsapp');
            $table->boolean('price_hidden')->default(false)->after('is_free');

            $table->index(['latitude', 'longitude'], 'ads_latlng_index');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropIndex('ads_latlng_index');
            $table->dropConstrainedForeignId('district_id');
            $table->dropColumn([
                'district_name_free',
                'latitude',
                'longitude',
                'show_phone_publicly',
                'price_hidden',
            ]);
        });
    }
};
