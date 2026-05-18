<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->enum('seller_type', ['individual', 'dealer'])
                ->default('individual')
                ->after('user_id');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropColumn('seller_type');
        });
    }
};
