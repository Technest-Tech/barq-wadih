<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $this->setDealerCommission(35);
    }

    public function down(): void
    {
        $this->setDealerCommission(99);
    }

    private function setDealerCommission(int $amount): void
    {
        $rootId = DB::table('categories')->where('slug', 'cars')->value('id');
        if ($rootId === null) {
            return;
        }

        $ids = [(int) $rootId];
        $parents = [(int) $rootId];
        while ($parents !== []) {
            $children = DB::table('categories')
                ->whereIn('parent_id', $parents)
                ->pluck('id')
                ->map(static fn ($id): int => (int) $id)
                ->all();
            $children = array_values(array_diff($children, $ids));
            $ids = array_merge($ids, $children);
            $parents = $children;
        }

        DB::table('categories')->whereIn('id', $ids)->update([
            'deferred_commission_dealer' => $amount,
            'updated_at' => now(),
        ]);
    }
};
