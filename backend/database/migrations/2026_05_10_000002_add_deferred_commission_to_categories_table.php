<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds fixed-SAR deferred commission amounts and a trigger type to categories.
 *
 * Client pricing model:
 *   Cars individual  → 20 SAR upfront (publish_fee_individual) + 100 SAR deferred after sale
 *   Cars dealer      → 10 SAR upfront (publish_fee_dealer)     + 70 SAR deferred after sale
 *   Others           → 3 SAR upfront                          + 7 SAR deferred after 90 days
 *   Jobs             → free (is_free = true)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->decimal('deferred_commission_individual', 8, 2)
                ->nullable()
                ->after('publish_fee_dealer');

            $table->decimal('deferred_commission_dealer', 8, 2)
                ->nullable()
                ->after('deferred_commission_individual');

            // after_sale    → collected when seller declares the item sold
            // after_90_days → collected automatically after 90-day listing window
            $table->enum('commission_trigger', ['after_sale', 'after_90_days'])
                ->default('after_sale')
                ->after('deferred_commission_dealer');
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropColumn([
                'deferred_commission_individual',
                'deferred_commission_dealer',
                'commission_trigger',
            ]);
        });
    }
};
