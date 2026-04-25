<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// ── Sprint 5: Ad expiry ────────────────────────────────────────────────────
Schedule::command('ads:expire')->daily();

// ── Sprint 12: Banner auto-deactivation ────────────────────────────────────
Schedule::command('banners:deactivate-expired')->daily();

// ── Sprint 13: Boost expiry ────────────────────────────────────────────────
Schedule::command('boosts:expire')->hourly();

// ── Sprint 17: Scheduled notification campaigns ───────────────────────────
Schedule::command('campaigns:send-scheduled')->everyFiveMinutes();
