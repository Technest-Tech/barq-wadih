<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parent_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('name_ar', 100);
            $table->string('name_en', 100);
            $table->string('slug', 120)->unique();
            $table->string('icon', 500)->nullable();
            $table->string('image', 500)->nullable();
            $table->text('description_ar')->nullable();
            $table->text('description_en')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->boolean('is_free')->default(false);
            $table->decimal('commission_rate', 5, 4)->nullable();
            $table->string('meta_keywords', 500)->nullable();
            $table->unsignedInteger('ads_count')->default(0);
            $table->json('prohibited_keywords')->nullable();
            $table->timestamps();

            $table->index('is_active');
            $table->index('sort_order');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('categories');
    }
};
