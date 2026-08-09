<?php

use App\Http\Controllers\Api\V1\AdController;
use App\Http\Controllers\Api\V1\AdPaymentController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\DistrictController;
use App\Http\Controllers\Api\V1\BannerController;
use App\Http\Controllers\Api\V1\BoostController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\CategoryFollowController;
use App\Http\Controllers\Api\V1\ChatController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\FavoriteController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\RatingController;
use App\Http\Controllers\Api\V1\RegionController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\QuestionController;
use App\Http\Controllers\Api\V1\SearchController;
use App\Http\Controllers\Api\V1\UserFollowController;
use App\Http\Controllers\Api\V1\UserProfileController;
use App\Http\Controllers\Api\V1\ContactController;
use App\Http\Controllers\Api\V1\StaticPageController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API V1 Routes
|--------------------------------------------------------------------------
|
| All routes prefixed with /api/v1/
| Middleware: ForceJsonResponse, SetLocale
|
*/

// ── Public ────────────────────────────────────────────────────────────────────
Route::get('health', HealthController::class)->name('health');

// ── Sprint 4: Categories & Regions — public, no auth required ────────────────
Route::get('categories',               [CategoryController::class, 'index'])->name('categories.index');
Route::get('regions',                  [RegionController::class, 'index'])->name('regions.index');
Route::get('regions/{slug}/cities',    [RegionController::class, 'cities'])->name('regions.cities');
Route::get('cities',                   [RegionController::class, 'allCities'])->name('cities.index');
Route::get('cities/{city}/districts',  [DistrictController::class, 'index'])->name('cities.districts');

// ── Payment webhook (PSP-callable, signature-verified inside controller) ──
Route::post('payment/webhook/moyasar', [AdPaymentController::class, 'webhook'])->name('payment.webhook.moyasar');

// ── Sprint 5: Ads — public read ───────────────────────────────────────────────
Route::get('ads',                      [AdController::class, 'index'])->name('ads.index');
Route::get('ads/commission-preview',   [AdController::class, 'commissionPreview'])->name('ads.commission-preview');
Route::get('ads/mine',                 [AdController::class, 'myAds'])->middleware('auth:sanctum')->name('ads.mine');
Route::get('ads/{ad}',                 [AdController::class, 'show'])->name('ads.show');
Route::get('categories/{category}/fields', [AdController::class, 'categoryFields'])->name('categories.fields');

// Sprint 13: Boost pricing & cooldown rules (public — clients read it before acting)
Route::get('boost-config',             [BoostController::class, 'config'])->name('boost.config');

// ── Sprint 7: Search — public, Meilisearch-powered with Eloquent fallback ─────
Route::get('search',                   [SearchController::class, 'index'])->name('search.index');
Route::get('search/suggestions',       [SearchController::class, 'suggestions'])->name('search.suggestions');
Route::get('search/popular',           [SearchController::class, 'popular'])->name('search.popular');

// ── Sprint 12: Banners — public, no auth required ──────────────────────────
Route::get('banners',                   [BannerController::class, 'index'])->name('banners.index');
Route::post('banners/{banner}/click',   [BannerController::class, 'click'])->name('banners.click');

// ── Contact Us — public categories read, optional-auth submit ─────────────────
Route::get('contact/categories',  [ContactController::class, 'categories'])->name('contact.categories');
Route::post('contact',            [ContactController::class, 'store'])->name('contact.store');

// ── Static Pages — public CMS content ─────────────────────────────────────────
Route::get('pages/{slug}',        [StaticPageController::class, 'show'])->name('pages.show');

// ── Questions — public read ───────────────────────────────────────────────────
Route::get('ads/{ad}/questions',             [QuestionController::class, 'index'])->name('questions.index');

// ── Sprint 9: Ratings & Reports — public reads ────────────────────────────────
Route::get('ads/{ad}/ratings',               [RatingController::class, 'index'])->name('ratings.index');
Route::get('users/{user}',                   [UserProfileController::class, 'show'])->name('users.show');
Route::get('users/{user}/ads',               [UserProfileController::class, 'ads'])->name('users.ads');
Route::get('users/{user}/ratings',           [RatingController::class, 'userRatings'])->name('users.ratings');
Route::get('users/{user}/rating-summary',    [RatingController::class, 'summary'])->name('users.rating-summary');
Route::get('reports/reasons',               [ReportController::class, 'reasons'])->name('reports.reasons');

// ── Auth — rate limited (throttle:auth defined in AppServiceProvider) ─────────
Route::prefix('auth')->name('auth.')->middleware('throttle:auth')->group(function () {
    Route::post('register',  [AuthController::class, 'register'])->name('register');
    Route::post('login',     [AuthController::class, 'login'])->name('login');
    Route::post('firebase',  [AuthController::class, 'firebase'])->name('firebase');
});

// ── Protected — requires Sanctum token ─────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {
    // Auth profile
    Route::prefix('auth')->name('auth.')->group(function () {
        Route::get('me',           [AuthController::class, 'me'])->name('me');
        Route::put('me',           [AuthController::class, 'updateProfile'])->name('me.update');
        Route::post('me/avatar',   [AuthController::class, 'uploadAvatar'])->name('me.avatar');
        Route::post('me/cover',    [AuthController::class, 'uploadCover'])->name('me.cover');
        Route::post('logout',      [AuthController::class, 'logout'])->name('logout');
        Route::post('logout-all',  [AuthController::class, 'logoutAll'])->name('logout.all');
    });

    // Sprint 5: Ads — authenticated write
    Route::post('ads',             [AdController::class, 'store'])->name('ads.store');
    Route::post('ads/{ad}/sold',   [AdController::class, 'markSold'])->name('ads.sold');
    Route::patch('ads/{ad}',       [AdController::class, 'update'])->name('ads.update');
    Route::delete('ads/{ad}',      [AdController::class, 'destroy'])->name('ads.destroy');

    // Sprint 13: Boost / Refresh — controller + service existed but were never routed.
    Route::post('ads/{ad}/boost',         [BoostController::class, 'boost'])->name('ads.boost');
    Route::post('ads/{ad}/refresh',       [BoostController::class, 'refresh'])->name('ads.refresh');
    Route::get('ads/{ad}/boost-history',  [BoostController::class, 'history'])->name('ads.boost.history');

    // Publish-fee payment lifecycle (mocked driver in dev, Moyasar later)
    Route::post('ads/{ad}/payment/init',    [AdPaymentController::class, 'init'])->name('ads.payment.init');
    Route::post('ads/{ad}/payment/confirm', [AdPaymentController::class, 'confirm'])->name('ads.payment.confirm');
    // Manual bank-transfer receipt upload (until PSP is live) — goes to admin review.
    Route::post('ads/{ad}/payment/proof',   [AdPaymentController::class, 'uploadProof'])->name('ads.payment.proof');

    // Sprint 9: Ratings
    Route::post('ads/{ad}/ratings',          [RatingController::class, 'store'])->name('ratings.store');
    Route::delete('ratings/{rating}',        [RatingController::class, 'destroy'])->name('ratings.destroy');

    // Sprint 9: Favorites
    Route::get('favorites',                  [FavoriteController::class, 'index'])->name('favorites.index');
    Route::post('ads/{ad}/favorite',         [FavoriteController::class, 'toggle'])->name('favorites.toggle');
    Route::get('ads/{ad}/favorite-status',   [FavoriteController::class, 'status'])->name('favorites.status');

    // Sprint 9: Reports
    Route::post('ads/{ad}/report',           [ReportController::class, 'store'])->name('reports.store');

    // Questions & Replies
    Route::post('ads/{ad}/questions',           [QuestionController::class, 'store'])->name('questions.store');
    Route::post('questions/{question}/reply',   [QuestionController::class, 'reply'])->name('questions.reply');

    // Sprint 8: Chat — Firestore companion API
    Route::prefix('chat')->name('chat.')->group(function () {
        Route::get('token',                        [ChatController::class, 'token'])->name('token');
        Route::get('conversations',                [ChatController::class, 'index'])->name('conversations.index');
        Route::post('conversations',               [ChatController::class, 'store'])->name('conversations.store');
        Route::post('conversations/{id}/notify',   [ChatController::class, 'notify'])->name('conversations.notify');
    });

    // Sprint 10: Devices
    Route::post('devices',                               [DeviceController::class, 'store'])->name('devices.store');
    Route::delete('devices',                             [DeviceController::class, 'destroy'])->name('devices.destroy');

    // Sprint 10: Category Follow
    Route::post('categories/{category}/follow',          [CategoryFollowController::class, 'toggle'])->name('categories.follow');
    Route::get('categories/{category}/follow-status',    [CategoryFollowController::class, 'status'])->name('categories.follow.status');
    Route::get('follows',                                [CategoryFollowController::class, 'index'])->name('follows.index');

    // Seller (User) Follow
    Route::post('users/{user}/follow',                   [UserFollowController::class, 'toggle'])->name('users.follow');
    Route::get('users/{user}/follow-status',             [UserFollowController::class, 'status'])->name('users.follow.status');
    Route::get('seller-follows',                         [UserFollowController::class, 'index'])->name('seller-follows.index');

    // Sprint 10: Notifications
    Route::get('notifications',                          [NotificationController::class, 'index'])->name('notifications.index');
    Route::post('notifications/{notification}/read',     [NotificationController::class, 'markRead'])->name('notifications.read');
    Route::post('notifications/read-all',                [NotificationController::class, 'markAllRead'])->name('notifications.readAll');
    Route::get('notifications/unread-count',             [NotificationController::class, 'unreadCount'])->name('notifications.unreadCount');
});

