<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Contact & verification
            $table->string('phone', 20)->nullable()->unique()->after('email');
            $table->timestamp('phone_verified_at')->nullable()->after('phone');

            // Profile
            $table->string('avatar', 500)->nullable()->after('password');
            $table->text('bio')->nullable()->after('avatar');

            // Location
            $table->foreignId('region_id')->nullable()->constrained()->nullOnDelete()->after('bio');
            $table->foreignId('city_id')->nullable()->constrained()->nullOnDelete()->after('region_id');

            // Flags
            $table->boolean('is_dealer')->default(false)->after('city_id');
            $table->boolean('is_verified')->default(false)->after('is_dealer');
            $table->boolean('is_active')->default(true)->after('is_verified');

            // Role & auth
            $table->string('role', 20)->default('user')->after('is_active');
            $table->string('firebase_uid', 128)->nullable()->unique()->after('role');
            $table->string('locale', 5)->default('ar')->after('firebase_uid');

            // Denormalized counters
            $table->unsignedInteger('total_ads_count')->default(0)->after('locale');
            $table->decimal('avg_rating', 3, 2)->default(0.00)->after('total_ads_count');
            $table->unsignedInteger('rating_count')->default(0)->after('avg_rating');
            $table->unsignedInteger('commissions_paid_count')->default(0)->after('rating_count');
            $table->unsignedInteger('commissions_due_count')->default(0)->after('commissions_paid_count');

            // Tracking
            $table->timestamp('last_active_at')->nullable()->after('commissions_due_count');

            // Soft deletes
            $table->softDeletes();

            // Indexes
            $table->index('is_active');
            $table->index('is_verified');
            $table->index('role');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Drop foreign keys
            $table->dropConstrainedForeignId('region_id');
            $table->dropConstrainedForeignId('city_id');

            // Drop indexes
            $table->dropIndex(['is_active']);
            $table->dropIndex(['is_verified']);
            $table->dropIndex(['role']);

            // Drop columns
            $table->dropColumn([
                'phone', 'phone_verified_at', 'avatar', 'bio',
                'is_dealer', 'is_verified', 'is_active',
                'role', 'firebase_uid', 'locale',
                'total_ads_count', 'avg_rating', 'rating_count',
                'commissions_paid_count', 'commissions_due_count',
                'last_active_at', 'deleted_at',
            ]);
        });
    }
};
