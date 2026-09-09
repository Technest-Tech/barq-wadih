<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropUnique(['reporter_id', 'ad_id']);
            $table->unsignedBigInteger('ad_id')->nullable()->change();
            $table->foreignId('reported_user_id')
                ->nullable()
                ->after('ad_id')
                ->constrained('users')
                ->nullOnDelete();
            $table->string('conversation_id', 160)->nullable()->after('reported_user_id');

            $table->unique(['reporter_id', 'ad_id']);
            $table->unique(['reporter_id', 'reported_user_id']);
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropUnique(['reporter_id', 'reported_user_id']);
            $table->dropConstrainedForeignId('reported_user_id');
            $table->dropColumn('conversation_id');
            $table->dropUnique(['reporter_id', 'ad_id']);
            $table->unsignedBigInteger('ad_id')->nullable(false)->change();
            $table->unique(['reporter_id', 'ad_id']);
        });
    }
};
