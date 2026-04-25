<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('fcm_token', 500);
            $table->string('device_type', 10); // ios, android, web (DeviceType enum)
            $table->string('device_name', 100)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index('fcm_token');
            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_devices');
    }
};
