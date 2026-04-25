<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('category_fields', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->string('field_key', 50);
            $table->string('label_ar', 100);
            $table->string('label_en', 100);
            $table->string('field_type', 20); // FieldType enum
            $table->json('options')->nullable();
            $table->boolean('is_required')->default(false);
            $table->boolean('is_filterable')->default(true);
            $table->integer('sort_order')->default(0);
            $table->string('placeholder_ar', 200)->nullable();
            $table->string('placeholder_en', 200)->nullable();
            $table->json('validation_rules')->nullable();
            $table->timestamps();

            $table->index('field_key');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('category_fields');
    }
};
