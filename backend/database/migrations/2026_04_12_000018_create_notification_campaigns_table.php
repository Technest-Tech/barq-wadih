<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_campaigns', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->constrained('users');
            $table->string('title_ar', 200);
            $table->string('title_en', 200)->nullable();
            $table->text('body_ar');
            $table->text('body_en')->nullable();
            $table->string('target_type', 20); // CampaignTargetType enum
            $table->foreignId('target_city_id')->nullable()->constrained('cities')->nullOnDelete();
            $table->foreignId('target_category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->json('target_user_ids')->nullable();
            $table->json('data')->nullable();
            $table->string('status', 15)->default('draft'); // CampaignStatus enum
            $table->timestamp('scheduled_at')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->unsignedInteger('recipients_count')->default(0);
            $table->unsignedInteger('delivered_count')->default(0);
            $table->timestamps();

            $table->index('status');
            $table->index('scheduled_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_campaigns');
    }
};
