<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Named route required by Laravel auth middleware. API clients hit this when
// they call protected endpoints without a Sanctum token — return 401 JSON.
Route::get('/login', function () {
    return response()->json([
        'success' => false,
        'message' => 'Unauthenticated.',
    ], 401);
})->name('login');
