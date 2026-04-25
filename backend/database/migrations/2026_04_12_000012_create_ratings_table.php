<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('rater_id')->constrained('users');
            $table->foreignId('rated_user_id')->constrained('users');
            $table->foreignId('ad_id')->nullable()->constrained();
            $table->unsignedTinyInteger('stars');
            $table->text('comment')->nullable();
            $table->boolean('pledge_accepted')->default(false);
            $table->boolean('is_approved')->default(true);
            $table->text('admin_note')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['rater_id', 'rated_user_id', 'ad_id']);
            $table->index('is_approved');
            $table->index('stars');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ratings');
    }
};
