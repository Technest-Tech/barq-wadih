<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('commission_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->foreignId('ad_id')->constrained();
            $table->decimal('sale_price', 12, 2);
            $table->decimal('commission_rate', 5, 4);
            $table->decimal('commission_amount', 10, 2);
            $table->boolean('is_flat_fee')->default(false);
            $table->string('payment_status', 20)->default('pending'); // CommissionStatus enum values
            $table->string('payment_method', 20)->nullable(); // PaymentMethod enum
            $table->string('payment_gateway', 50)->nullable();
            $table->string('gateway_transaction_id', 255)->nullable();
            $table->json('gateway_response')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index('payment_status');
            $table->index('paid_at');
            $table->index('gateway_transaction_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('commission_payments');
    }
};
