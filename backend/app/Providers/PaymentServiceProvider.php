<?php

namespace App\Providers;

use App\Services\MockPaymentService;
use App\Services\MoyasarPaymentService;
use App\Services\PaymentService;
use Illuminate\Support\ServiceProvider;

/**
 * Picks the concrete PaymentService implementation based on config.
 * Defaults to the mock (auto-confirming) driver — switch to moyasar by
 * setting PAYMENT_DRIVER=moyasar in .env once the integration ships.
 */
class PaymentServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(PaymentService::class, function () {
            $driver = (string) config('services.payment.driver', env('PAYMENT_DRIVER', 'mock'));

            return match ($driver) {
                'moyasar' => new MoyasarPaymentService(),
                default   => new MockPaymentService(),
            };
        });
    }

    public function boot(): void {}
}
