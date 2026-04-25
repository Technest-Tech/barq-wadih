<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ad_boosts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ad_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->timestamp('boosted_at');
            $table->timestamp('expires_at')->nullable();
            $table->string('boost_type', 10)->default('refresh'); // BoostType enum
            $table->timestamp('created_at')->useCurrent();

            $table->index('boosted_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ad_boosts');
    }
};
