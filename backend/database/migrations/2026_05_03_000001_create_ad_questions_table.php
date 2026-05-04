<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ad_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ad_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('parent_id')->nullable()->constrained('ad_questions')->cascadeOnDelete();
            $table->text('body');
            $table->timestamps();

            $table->index(['ad_id', 'parent_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ad_questions');
    }
};
