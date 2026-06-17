<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contact_submissions', function (Blueprint $table) {
            $table->string('category')->nullable()->change();
            $table->string('category_label')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('contact_submissions', function (Blueprint $table) {
            $table->string('category')->nullable(false)->change();
            $table->string('category_label')->nullable(false)->change();
        });
    }
};
