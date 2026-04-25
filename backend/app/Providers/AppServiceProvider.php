<?php

namespace App\Providers;

use App\Models\Ad;
use App\Observers\AdObserver;
use App\Policies\AdPolicy;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void {}

    public function boot(): void
    {
        // Rate limiter for auth endpoints — 10 attempts per minute per IP
        RateLimiter::for('auth', function (Request $request) {
            return Limit::perMinute(10)->by($request->ip());
        });

        // Policies
        Gate::policy(Ad::class, AdPolicy::class);

        // Observers
        Ad::observe(AdObserver::class);
    }
}
