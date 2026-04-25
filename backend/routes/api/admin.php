<?php

use App\Http\Controllers\Api\V1\Admin\AdminAdController;
use App\Http\Controllers\Api\V1\Admin\AdminAnalyticsController;
use App\Http\Controllers\Api\V1\Admin\AdminBannerController;
use App\Http\Controllers\Api\V1\Admin\AdminCategoryController;
use App\Http\Controllers\Api\V1\Admin\AdminCommissionController;
use App\Http\Controllers\Api\V1\Admin\AdminNotificationController;
use App\Http\Controllers\Api\V1\Admin\AdminRegionController;
use App\Http\Controllers\Api\V1\Admin\AdminReportController;
use App\Http\Controllers\Api\V1\Admin\AdminSettingsController;
use App\Http\Controllers\Api\V1\Admin\AdminStaticPageController;
use App\Http\Controllers\Api\V1\Admin\AdminUserController;
use App\Http\Controllers\Api\V1\Admin\DashboardController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Admin API Routes — Sprint 14+
|--------------------------------------------------------------------------
|
| Prefix:     /api/v1/admin
| Middleware:  force.json, set.locale, auth:sanctum, admin
|
| These routes are isolated from user-facing routes to prevent
| merge conflicts with parallel sprint work.
|
*/

Route::prefix('v1/admin')
    ->middleware(['force.json', 'set.locale', 'auth:sanctum', 'admin'])
    ->name('admin.')
    ->group(function () {

        // ── Sprint 14: Dashboard ────────────────────────────────────────
        Route::get('dashboard/stats', [DashboardController::class, 'stats'])
            ->name('dashboard.stats');

        // ── Sprint 14: User Management ──────────────────────────────────
        Route::get('users',                [AdminUserController::class, 'index'])->name('users.index');
        Route::get('users/{user}',         [AdminUserController::class, 'show'])->name('users.show');
        Route::patch('users/{user}/status', [AdminUserController::class, 'updateStatus'])->name('users.status');
        Route::patch('users/{user}/role',   [AdminUserController::class, 'updateRole'])->name('users.role');

        // ── Sprint 15: Ad Moderation ────────────────────────────────────
        Route::get('ads',                  [AdminAdController::class, 'index'])->name('ads.index');
        Route::get('ads/{ad}',             [AdminAdController::class, 'show'])->name('ads.show');
        Route::post('ads/{ad}/approve',    [AdminAdController::class, 'approve'])->name('ads.approve');
        Route::post('ads/{ad}/reject',     [AdminAdController::class, 'reject'])->name('ads.reject');
        Route::delete('ads/{ad}',          [AdminAdController::class, 'destroy'])->name('ads.destroy');
        Route::post('ads/{ad}/restore',    [AdminAdController::class, 'restore'])->name('ads.restore');

        // ── Sprint 15: Reports ──────────────────────────────────────────
        Route::get('reports',                    [AdminReportController::class, 'index'])->name('reports.index');
        Route::get('reports/{report}',           [AdminReportController::class, 'show'])->name('reports.show');
        Route::post('reports/{report}/resolve',  [AdminReportController::class, 'resolve'])->name('reports.resolve');
        Route::post('reports/{report}/dismiss',  [AdminReportController::class, 'dismiss'])->name('reports.dismiss');

        // ── Sprint 15: Category Management ──────────────────────────────
        Route::get('categories',                        [AdminCategoryController::class, 'index'])->name('categories.index');
        Route::post('categories',                       [AdminCategoryController::class, 'store'])->name('categories.store');
        Route::put('categories/{category}',             [AdminCategoryController::class, 'update'])->name('categories.update');
        Route::post('categories/{category}/toggle',     [AdminCategoryController::class, 'toggleActive'])->name('categories.toggle');
        Route::post('categories/reorder',               [AdminCategoryController::class, 'reorder'])->name('categories.reorder');
        Route::get('categories/{category}/fields',      [AdminCategoryController::class, 'fields'])->name('categories.fields');
        Route::post('categories/{category}/fields',     [AdminCategoryController::class, 'storeField'])->name('categories.fields.store');
        Route::put('fields/{field}',                    [AdminCategoryController::class, 'updateField'])->name('fields.update');
        Route::delete('fields/{field}',                 [AdminCategoryController::class, 'deleteField'])->name('fields.destroy');

        // ── Sprint 15: Region & City Management ─────────────────────────
        Route::get('regions',                  [AdminRegionController::class, 'index'])->name('regions.index');
        Route::get('regions/{region}/cities',  [AdminRegionController::class, 'cities'])->name('regions.cities');
        Route::post('regions/{region}/toggle', [AdminRegionController::class, 'toggleRegion'])->name('regions.toggle');
        Route::post('cities/{city}/toggle',    [AdminRegionController::class, 'toggleCity'])->name('cities.toggle');
        Route::put('cities/{city}',            [AdminRegionController::class, 'updateCity'])->name('cities.update');

        // ── Sprint 15: Static Pages CMS ─────────────────────────────────
        Route::get('pages',          [AdminStaticPageController::class, 'index'])->name('pages.index');
        Route::get('pages/{page}',   [AdminStaticPageController::class, 'show'])->name('pages.show');
        Route::post('pages',         [AdminStaticPageController::class, 'store'])->name('pages.store');
        Route::put('pages/{page}',   [AdminStaticPageController::class, 'update'])->name('pages.update');
        Route::delete('pages/{page}',[AdminStaticPageController::class, 'destroy'])->name('pages.destroy');

        // ── Sprint 16: Commission Management ─────────────────────────────
        Route::get('commissions/summary',              [AdminCommissionController::class, 'summary'])->name('commissions.summary');
        Route::get('commissions/export',               [AdminCommissionController::class, 'export'])->name('commissions.export');
        Route::get('commissions',                      [AdminCommissionController::class, 'index'])->name('commissions.index');
        Route::get('commissions/{commission}',          [AdminCommissionController::class, 'show'])->name('commissions.show');
        Route::patch('commissions/{commission}/status', [AdminCommissionController::class, 'updateStatus'])->name('commissions.status');

        // ── Sprint 16: Analytics ─────────────────────────────────────────
        Route::get('analytics/revenue',       [AdminAnalyticsController::class, 'revenue'])->name('analytics.revenue');
        Route::get('analytics/ads-by-city',   [AdminAnalyticsController::class, 'adsByCity'])->name('analytics.ads-by-city');
        Route::get('analytics/search-terms',  [AdminAnalyticsController::class, 'searchTerms'])->name('analytics.search-terms');
        Route::get('analytics/zero-results',  [AdminAnalyticsController::class, 'zeroResults'])->name('analytics.zero-results');

        // ── Sprint 17: Notification Campaigns ────────────────────────────
        Route::get('notifications/stats',                        [AdminNotificationController::class, 'stats'])->name('notifications.stats');
        Route::get('notifications/campaigns',                    [AdminNotificationController::class, 'index'])->name('notifications.campaigns.index');
        Route::post('notifications/campaigns',                   [AdminNotificationController::class, 'store'])->name('notifications.campaigns.store');
        Route::get('notifications/campaigns/{campaign}',         [AdminNotificationController::class, 'show'])->name('notifications.campaigns.show');
        Route::put('notifications/campaigns/{campaign}',         [AdminNotificationController::class, 'update'])->name('notifications.campaigns.update');
        Route::delete('notifications/campaigns/{campaign}',      [AdminNotificationController::class, 'destroy'])->name('notifications.campaigns.destroy');
        Route::post('notifications/campaigns/{campaign}/send',   [AdminNotificationController::class, 'send'])->name('notifications.campaigns.send');
        Route::post('notifications/campaigns/{campaign}/schedule', [AdminNotificationController::class, 'schedule'])->name('notifications.campaigns.schedule');

        // ── Sprint 17: Banner Management ─────────────────────────────────
        Route::get('banners',                    [AdminBannerController::class, 'index'])->name('banners.index');
        Route::post('banners',                   [AdminBannerController::class, 'store'])->name('banners.store');
        Route::get('banners/{banner}',           [AdminBannerController::class, 'show'])->name('banners.show');
        Route::put('banners/{banner}',           [AdminBannerController::class, 'update'])->name('banners.update');
        Route::delete('banners/{banner}',        [AdminBannerController::class, 'destroy'])->name('banners.destroy');
        Route::post('banners/{banner}/toggle',   [AdminBannerController::class, 'toggle'])->name('banners.toggle');
        Route::get('banners/{banner}/analytics', [AdminBannerController::class, 'analytics'])->name('banners.analytics');

        // ── Sprint 17: System Settings ───────────────────────────────────
        Route::get('settings',              [AdminSettingsController::class, 'index'])->name('settings.index');
        Route::put('settings/bulk',         [AdminSettingsController::class, 'bulkUpdate'])->name('settings.bulk');
        Route::get('settings/{key}',        [AdminSettingsController::class, 'show'])->name('settings.show');
        Route::put('settings/{key}',        [AdminSettingsController::class, 'update'])->name('settings.update');
    });

