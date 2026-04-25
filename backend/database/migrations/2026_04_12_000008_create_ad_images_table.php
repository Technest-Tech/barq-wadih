<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ad_images', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ad_id')->constrained()->cascadeOnDelete();
            $table->string('image_url', 500);
            $table->string('thumbnail_url', 500)->nullable();
            $table->integer('sort_order')->default(0);
            $table->unsignedInteger('file_size')->nullable();
            $table->unsignedInteger('width')->nullable();
            $table->unsignedInteger('height')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index('sort_order');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ad_images');
    }
};
