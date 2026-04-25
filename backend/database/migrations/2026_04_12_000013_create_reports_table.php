<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reporter_id')->constrained('users');
            $table->foreignId('ad_id')->constrained();
            $table->string('reason', 30); // ReportReason enum
            $table->text('description')->nullable();
            $table->string('status', 20)->default('pending'); // ReportStatus enum
            $table->foreignId('admin_id')->nullable()->constrained('users');
            $table->string('admin_action', 20)->nullable(); // AdminAction enum
            $table->text('admin_note')->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->unique(['reporter_id', 'ad_id']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};
