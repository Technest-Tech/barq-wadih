<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The verification badge is granted by hand once a seller has paid for it, so
 * the grant needs a paper trail: who pressed the button, when, and against
 * which payment. `is_verified` stays the flag every read path already checks —
 * these columns only record how it got set.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('verified_at')->nullable()->after('is_verified');
            $table->foreignId('verified_by')->nullable()->after('verified_at')
                ->constrained('users')->nullOnDelete();
            $table->string('verification_note', 500)->nullable()->after('verified_by');
        });

        // Sellers verified before this migration keep their badge with a null
        // grant date — back-filling one would invent an audit record.
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('verified_by');
            $table->dropColumn(['verified_at', 'verification_note']);
        });
    }
};
