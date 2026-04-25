<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->constrained();
            $table->foreignId('city_id')->constrained();
            $table->foreignId('region_id')->constrained();
            $table->string('title', 200);
            $table->text('description');
            $table->decimal('price', 12, 2)->nullable();
            $table->boolean('is_negotiable')->default(false);
            $table->boolean('is_free')->default(false);

            // Status enums (stored as strings, cast via PHP enums)
            $table->string('status', 20)->default('active');
            $table->string('moderation_status', 20)->default('approved');
            $table->text('moderation_note')->nullable();

            // Counters
            $table->unsignedInteger('views_count')->default(0);
            $table->unsignedInteger('favorites_count')->default(0);
            $table->unsignedInteger('chats_count')->default(0);

            // Contact
            $table->string('contact_phone', 20)->nullable();
            $table->string('contact_whatsapp', 20)->nullable();

            // Commission
            $table->decimal('commission_amount', 10, 2)->nullable();
            $table->string('commission_status', 20)->default('not_applicable');
            $table->timestamp('sale_declared_at')->nullable();

            // Boost
            $table->boolean('is_boosted')->default(false);
            $table->timestamp('boosted_until')->nullable();

            // Lifecycle
            $table->boolean('pledge_accepted')->default(false);
            $table->timestamp('expires_at');
            $table->timestamp('expiry_notified_at')->nullable();
            $table->timestamp('published_at')->nullable();

            $table->timestamps();
            $table->softDeletes();

            // Single-column indexes
            $table->index('status');
            $table->index('moderation_status');
            $table->index('price');
            $table->index('is_boosted');
            $table->index('expires_at');
            $table->index('published_at');
            $table->index('commission_status');

            // Composite indexes for feed queries
            $table->index(['status', 'category_id', 'city_id', 'published_at'], 'ads_feed_index');
            $table->index(['status', 'is_boosted', 'published_at'], 'ads_boosted_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ads');
    }
};
