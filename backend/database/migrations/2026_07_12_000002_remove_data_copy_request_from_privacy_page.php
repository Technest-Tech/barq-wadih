<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $page = DB::table('static_pages')->where('slug', 'privacy')->first();

        if (! $page) {
            return;
        }

        // Static pages are admin-editable, so strip the bullet in place rather
        // than overwriting the whole page from the seeder.
        $strip = static function (?string $html, string $bullet): ?string {
            if ($html === null) {
                return null;
            }

            return preg_replace('/^\s*<li>' . preg_quote($bullet, '/') . '<\/li>\R?/mu', '', $html);
        };

        DB::table('static_pages')->where('id', $page->id)->update([
            'content_ar' => $strip($page->content_ar, 'طلب نسخة من بياناتك عبر صفحة التواصل.'),
            'content_en' => $strip($page->content_en, 'Request a copy of your data via the Contact page.'),
        ]);
    }

    public function down(): void
    {
        // Not reversible — the clause is intentionally removed.
    }
};
