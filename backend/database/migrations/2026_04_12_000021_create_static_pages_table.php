<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('static_pages', function (Blueprint $table) {
            $table->id();
            $table->string('slug', 120)->unique();
            $table->string('title_ar', 200);
            $table->string('title_en', 200);
            $table->longText('content_ar');
            $table->longText('content_en');
            $table->boolean('is_published')->default(true);
            $table->string('meta_description_ar', 300)->nullable();
            $table->string('meta_description_en', 300)->nullable();
            $table->timestamps();

            $table->index('is_published');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('static_pages');
    }
};
