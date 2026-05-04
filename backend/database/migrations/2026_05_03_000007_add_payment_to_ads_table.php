<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Records the per-ad publish-fee payment lifecycle. The ad itself flips into
 * AdStatus::PendingPayment until payment_status is `paid`. Provider/reference
 * are PSP-agnostic so MockPaymentService and a future MoyasarPaymentService can
 * write into the same columns.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->string('payment_status', 20)->default('not_required')->after('commission_status');
            $table->decimal('payment_amount', 10, 2)->nullable()->after('payment_status');
            $table->string('payment_provider', 20)->nullable()->after('payment_amount');
            $table->string('payment_reference', 120)->nullable()->after('payment_provider');
            $table->timestamp('paid_at')->nullable()->after('payment_reference');

            $table->index('payment_status');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropIndex(['payment_status']);
            $table->dropColumn([
                'payment_status',
                'payment_amount',
                'payment_provider',
                'payment_reference',
                'paid_at',
            ]);
        });
    }
};
