<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Bank-transfer proof workflow. Until the PSP (Moyasar) integration is live,
 * sellers pay the publish fee by manual bank transfer and upload a screenshot
 * of the transfer. The ad stays in PendingPayment until an admin reviews the
 * proof and approves it (payment_status -> paid). A rejected proof records the
 * reason so the seller can re-upload a corrected one.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->string('payment_proof_url', 500)->nullable()->after('paid_at');
            $table->timestamp('payment_proof_uploaded_at')->nullable()->after('payment_proof_url');
            $table->string('payment_review_note', 500)->nullable()->after('payment_proof_uploaded_at');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropColumn([
                'payment_proof_url',
                'payment_proof_uploaded_at',
                'payment_review_note',
            ]);
        });
    }
};
