<?php

namespace Tests\Feature;

use App\Enums\AdStatus;
use App\Models\Ad;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
use App\Services\AdService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

/**
 * Ads stay visible for 3 months, then get hidden — never deleted — and the
 * owner brings them back with "ترقية".
 */
class AdVisibilityWindowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Keep model writes off the search engine — this suite is about the
        // visibility window, not indexing.
        config(['scout.driver' => null]);
        // The ad observer dispatches follower push notifications, which the
        // sync queue would run straight into Firebase.
        Queue::fake();
    }

    private function makeAd(User $owner, array $overrides = []): Ad
    {
        $suffix = Region::count();

        $region = Region::create([
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => "riyadh-r{$suffix}",
            'is_active' => true,
        ]);
        $city = City::create([
            'region_id' => $region->id,
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => "riyadh-c{$suffix}",
            'is_active' => true,
        ]);
        $category = Category::create([
            'name_ar' => 'سيارات',
            'name_en' => 'Cars',
            'slug' => "cars-{$suffix}",
            'is_active' => true,
        ]);

        return Ad::create(array_merge([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'city_id' => $city->id,
            'region_id' => $region->id,
            'title' => 'سيارة للبيع',
            'description' => 'وصف الإعلان',
            'price' => 1000,
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
        ], $overrides));
    }

    public function test_a_new_ad_stays_visible_for_three_months(): void
    {
        $ad = $this->makeAd(User::factory()->create(['phone' => '+966500000101']));

        $this->assertEqualsWithDelta(
            now()->addMonths(3)->timestamp,
            $ad->expires_at->timestamp,
            60,
        );
    }

    public function test_the_expire_command_hides_the_ad_without_deleting_it(): void
    {
        $ad = $this->makeAd(
            User::factory()->create(['phone' => '+966500000102']),
            ['expires_at' => now()->subDay()],
        );

        Artisan::call('ads:expire');

        $ad->refresh();
        $this->assertSame(AdStatus::Expired, $ad->status);
        // Still on the books — hidden, not destroyed.
        $this->assertNull($ad->deleted_at);
        $this->assertDatabaseHas('ads', ['id' => $ad->id, 'status' => 'expired']);
    }

    public function test_renew_is_locked_while_the_ad_is_still_visible(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000103']);
        $ad = $this->makeAd($owner);

        $this->assertFalse($owner->can('renew', $ad));

        $this->actingAs($owner)
            ->postJson("/api/v1/ads/{$ad->id}/renew")
            ->assertForbidden();
    }

    public function test_the_owner_can_bring_a_hidden_ad_back(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000104']);
        $ad = $this->makeAd($owner, [
            'status' => AdStatus::Expired,
            'expires_at' => now()->subDay(),
            'published_at' => now()->subMonths(3),
            'expiry_notified_at' => now()->subWeek(),
        ]);

        $this->assertTrue($owner->can('renew', $ad));

        $response = $this->actingAs($owner)->postJson("/api/v1/ads/{$ad->id}/renew");

        $response->assertOk()->assertJsonPath('data.status', 'active');

        $ad->refresh();
        $this->assertSame(AdStatus::Active, $ad->status);
        $this->assertEqualsWithDelta(now()->addMonths(3)->timestamp, $ad->expires_at->timestamp, 60);
        $this->assertEqualsWithDelta(now()->timestamp, $ad->published_at->timestamp, 60);
        $this->assertNull($ad->expiry_notified_at);

        // And the button locks again now that it is visible.
        $this->assertFalse($owner->fresh()->can('renew', $ad));
    }

    public function test_a_stranger_cannot_renew_someone_elses_hidden_ad(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000105']);
        $stranger = User::factory()->create(['phone' => '+966500000106']);
        $ad = $this->makeAd($owner, ['status' => AdStatus::Expired, 'expires_at' => now()->subDay()]);

        $this->actingAs($stranger)
            ->postJson("/api/v1/ads/{$ad->id}/renew")
            ->assertForbidden();
    }

    public function test_my_ads_exposes_the_renew_flag_that_drives_the_button(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000107']);
        $visible = $this->makeAd($owner);
        $hidden = $this->makeAd($owner, ['status' => AdStatus::Expired, 'expires_at' => now()->subDay()]);

        $response = $this->actingAs($owner)->getJson('/api/v1/ads/mine')->assertOk();

        $flags = collect($response->json('data'))->pluck('can_renew', 'id');
        $this->assertFalse($flags[$visible->id]);
        $this->assertTrue($flags[$hidden->id]);
    }

    public function test_the_service_renews_without_sending_the_ad_back_to_moderation(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000108']);
        $ad = $this->makeAd($owner, ['status' => AdStatus::Expired, 'expires_at' => now()->subDay()]);

        $renewed = app(AdService::class)->renew($ad);

        $this->assertSame(AdStatus::Active, $renewed->status);
        $this->assertSame('approved', $renewed->moderation_status->value);
    }
}
