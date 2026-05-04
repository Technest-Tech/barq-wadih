<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds publish-fee columns to categories so admins can set per-category
 * pricing with separate rates for individuals vs dealers, and a flag for
 * whether the fee is later deducted from the seller's commission.
 *
 * Drives the mandatory pre-payment flow:
 *   - Individual fee  (e.g. cars: 20 SAR, others: 3 SAR)
 *   - Dealer fee      (e.g. cars: 10 SAR, others: 3 SAR)
 *   - Deductible flag (whether this fee is subtracted from final commission)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->decimal('publish_fee_individual', 8, 2)->nullable()->after('commission_rate');
            $table->decimal('publish_fee_dealer', 8, 2)->nullable()->after('publish_fee_individual');
            $table->boolean('fee_deductible_from_commission')->default(true)->after('publish_fee_dealer');
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropColumn([
                'publish_fee_individual',
                'publish_fee_dealer',
                'fee_deductible_from_commission',
            ]);
        });
    }
};
