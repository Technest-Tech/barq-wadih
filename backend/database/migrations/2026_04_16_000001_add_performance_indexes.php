<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Sprint 18: Add compound indexes for performance-critical queries.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Ads feed query: WHERE status = ? AND city_id = ? ORDER BY created_at DESC
        Schema::table('ads', function (Blueprint $table) {
            $table->index(['status', 'city_id', 'created_at'], 'ads_feed_idx');
            $table->index(['status', 'category_id', 'created_at'], 'ads_category_feed_idx');
        });

        // Search logs analytics: GROUP BY query ... ORDER BY created_at
        Schema::table('search_logs', function (Blueprint $table) {
            $table->index(['query', 'created_at'], 'search_logs_query_date_idx');
        });

        // Commission admin dashboard: WHERE payment_status = ? ORDER BY created_at
        Schema::table('commission_payments', function (Blueprint $table) {
            $table->index(['payment_status', 'created_at'], 'commissions_status_date_idx');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropIndex('ads_feed_idx');
            $table->dropIndex('ads_category_feed_idx');
        });

        Schema::table('search_logs', function (Blueprint $table) {
            $table->dropIndex('search_logs_query_date_idx');
        });

        Schema::table('commission_payments', function (Blueprint $table) {
            $table->dropIndex('commissions_status_date_idx');
        });
    }
};
