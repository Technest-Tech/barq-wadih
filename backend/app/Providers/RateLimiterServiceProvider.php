<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

class RateLimiterServiceProvider extends ServiceProvider
{
    /**
     * Bootstrap application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiters();
    }

    /**
     * Configure the rate limiters for the application.
     *
     * Rules per ARCHITECTURE.md §7.5:
     *   - auth:     5  requests / minute
     *   - api:      60 requests / minute
     *   - search:   30 requests / minute
     *   - upload:   20 requests / hour
     *   - ad-create: 10 requests / hour
     */
    private function configureRateLimiters(): void
    {
        // Auth endpoints (login, register, OTP)
        RateLimiter::for('auth', function (Request $request) {
            return Limit::perMinute(5)
                ->by($request->ip())
                ->response(function () {
                    return response()->json([
                        'success' => false,
                        'message' => 'تم تجاوز الحد المسموح من محاولات تسجيل الدخول، يرجى المحاولة بعد دقيقة',
                    ], 429);
                });
        });

        // General API endpoints
        RateLimiter::for('api', function (Request $request) {
            return Limit::perMinute(60)
                ->by(optional($request->user())->id ?: $request->ip());
        });

        // Search endpoints
        RateLimiter::for('search', function (Request $request) {
            return Limit::perMinute(30)
                ->by(optional($request->user())->id ?: $request->ip());
        });

        // File upload endpoints
        RateLimiter::for('upload', function (Request $request) {
            return Limit::perHour(20)
                ->by(optional($request->user())->id ?: $request->ip())
                ->response(function () {
                    return response()->json([
                        'success' => false,
                        'message' => 'تم تجاوز الحد المسموح من رفع الملفات لهذه الساعة',
                    ], 429);
                });
        });

        // Ad creation endpoint
        RateLimiter::for('ad-create', function (Request $request) {
            return Limit::perHour(10)
                ->by(optional($request->user())->id ?: $request->ip())
                ->response(function () {
                    return response()->json([
                        'success' => false,
                        'message' => 'تم تجاوز الحد المسموح من نشر الإعلانات لهذه الساعة',
                    ], 429);
                });
        });
    }
}
