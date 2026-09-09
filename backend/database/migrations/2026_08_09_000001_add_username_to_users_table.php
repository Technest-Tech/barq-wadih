<?php

use App\Services\UsernameGenerator;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Public @handle used in shareable profile links. Nullable so the
            // column can be added before the backfill below fills it in.
            $table->string('username', UsernameGenerator::MAX_LENGTH)
                ->nullable()
                ->unique()
                ->after('name');
        });

        $this->backfill();
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['username']);
            $table->dropColumn('username');
        });
    }

    /**
     * Give every existing user (including soft-deleted ones — their old links
     * must keep 404-ing rather than resolving to somebody else) a handle.
     *
     * Uniqueness is tracked in memory instead of re-querying per row, so this
     * stays one SELECT chunk + one UPDATE per user.
     */
    private function backfill(): void
    {
        $taken = [];

        DB::table('users')
            ->select('id', 'name')
            ->orderBy('id')
            ->chunk(500, function ($users) use (&$taken) {
                foreach ($users as $user) {
                    $handle = $this->pickHandle($user->name, (int) $user->id, $taken);
                    $taken[$handle] = true;

                    DB::table('users')->where('id', $user->id)->update(['username' => $handle]);
                }
            });
    }

    /** @param  array<string, true>  $taken */
    private function pickHandle(?string $name, int $id, array $taken): string
    {
        $base = UsernameGenerator::base($name);

        foreach ([$base, $base.'_'.$id] as $candidate) {
            if (! UsernameGenerator::isReserved($candidate) && ! isset($taken[$candidate])) {
                return $candidate;
            }
        }

        do {
            $candidate = $base.'_'.Str::lower(Str::random(6));
        } while (isset($taken[$candidate]));

        return $candidate;
    }
};
