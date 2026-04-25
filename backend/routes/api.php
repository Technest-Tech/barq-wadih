<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Versioned API routing. All routes go through version-specific files.
|
*/

Route::prefix('v1')
    ->middleware(['force.json', 'set.locale'])
    ->group(base_path('routes/api/v1.php'));

// ── Sprint 14+: Admin panel routes (isolated from user-facing routes) ────────
require base_path('routes/api/admin.php');
