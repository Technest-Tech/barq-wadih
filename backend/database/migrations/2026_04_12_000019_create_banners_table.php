<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('banners', function (Blueprint $table) {
            $table->id();
            $table->string('title', 200);
            $table->string('image_url', 500);
            $table->string('image_url_mobile', 500)->nullable();
            $table->string('link_type', 10)->default('none'); // BannerLinkType enum
            $table->foreignId('link_ad_id')->nullable()->constrained('ads')->nullOnDelete();
            $table->string('link_whatsapp', 20)->nullable();
            $table->string('link_url', 500)->nullable();
            $table->string('position', 20)->default('home_top'); // BannerPosition enum
            $table->integer('sort_order')->default(0);
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('impressions_count')->default(0);
            $table->unsignedInteger('clicks_count')->default(0);
            $table->string('advertiser_name', 200)->nullable();
            $table->string('advertiser_phone', 20)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('is_active');
            $table->index('position');
            $table->index(['is_active', 'position', 'starts_at', 'ends_at'], 'banners_active_query');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('banners');
    }
};
