<?php

namespace Tests\Feature;

use App\Enums\AdStatus;
use App\Enums\BoostType;
use App\Models\Ad;
use App\Models\AdBoost;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
use App\Services\AdService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

/**
 * "تحديث" bumps an ad back to the top of the feed, and the owner has to wait
 * 24 hours before doing it again.
 */
class AdRefreshCooldownTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['scout.driver' => null]);
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
            'published_at' => now()->subDays(2),
            'expires_at' => Ad::nextExpiry(),
        ], $overrides));
    }

    public function test_a_never_refreshed_ad_can_be_refreshed_right_away(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000201']);
        $ad = $this->makeAd($owner);

        $this->actingAs($owner)
            ->postJson("/api/v1/ads/{$ad->id}/refresh")
            ->assertOk();

        $ad->refresh();
        // Bumped to the top of the chronological feed.
        $this->assertEqualsWithDelta(now()->timestamp, $ad->published_at->timestamp, 60);
        $this->assertDatabaseHas('ad_boosts', [
            'ad_id' => $ad->id,
            'boost_type' => BoostType::Refresh->value,
        ]);
    }

    public function test_a_second_refresh_within_24_hours_is_rejected(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000202']);
        $ad = $this->makeAd($owner);

        $this->actingAs($owner)->postJson("/api/v1/ads/{$ad->id}/refresh")->assertOk();

        $publishedAfterFirst = $ad->fresh()->published_at;

        $this->travel(23)->hours();

        $this->actingAs($owner)
            ->postJson("/api/v1/ads/{$ad->id}/refresh")
            ->assertStatus(422);

        // The rejected bump left the feed position untouched.
        $this->assertSame(
            $publishedAfterFirst->timestamp,
            $ad->fresh()->published_at->timestamp,
        );
        $this->assertSame(1, AdBoost::where('ad_id', $ad->id)->count());
    }

    public function test_the_ad_can_be_refreshed_again_once_24_hours_have_passed(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000203']);
        $ad = $this->makeAd($owner);

        $this->actingAs($owner)->postJson("/api/v1/ads/{$ad->id}/refresh")->assertOk();

        $this->travel(24)->hours();

        $this->actingAs($owner)
            ->postJson("/api/v1/ads/{$ad->id}/refresh")
            ->assertOk();

        $this->assertEqualsWithDelta(
            now()->timestamp,
            $ad->fresh()->published_at->timestamp,
            60,
        );
        $this->assertSame(2, AdBoost::where('ad_id', $ad->id)->count());
    }

    public function test_the_cooldown_is_per_ad_not_per_user(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000204']);
        $first = $this->makeAd($owner);
        $second = $this->makeAd($owner);

        $this->actingAs($owner)->postJson("/api/v1/ads/{$first->id}/refresh")->assertOk();

        $this->actingAs($owner)
            ->postJson("/api/v1/ads/{$second->id}/refresh")
            ->assertOk();
    }

    public function test_my_ads_exposes_the_cooldown_that_locks_the_button(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000205']);
        $fresh = $this->makeAd($owner);
        $justRefreshed = $this->makeAd($owner);

        AdBoost::create([
            'ad_id' => $justRefreshed->id,
            'user_id' => $owner->id,
            'boosted_at' => now()->subHours(2),
            'expires_at' => null,
            'boost_type' => BoostType::Refresh->value,
        ]);

        $response = $this->actingAs($owner)->getJson('/api/v1/ads/mine')->assertOk();

        $rows = collect($response->json('data'))->keyBy('id');

        $this->assertTrue($rows[$fresh->id]['can_refresh']);
        $this->assertNull($rows[$fresh->id]['next_refresh_at']);

        $this->assertFalse($rows[$justRefreshed->id]['can_refresh']);
        $this->assertEqualsWithDelta(
            now()->addHours(22)->timestamp,
            strtotime($rows[$justRefreshed->id]['next_refresh_at']),
            60,
        );
    }

    public function test_the_cooldown_is_invisible_to_everyone_but_the_owner(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000206']);
        $stranger = User::factory()->create(['phone' => '+966500000207']);
        $ad = $this->makeAd($owner);

        $response = $this->actingAs($stranger)
            ->getJson("/api/v1/ads/{$ad->id}")
            ->assertOk();

        $this->assertNull($response->json('data.can_refresh'));
        $this->assertNull($response->json('data.next_refresh_at'));
    }

    public function test_a_stranger_cannot_refresh_someone_elses_ad(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000208']);
        $stranger = User::factory()->create(['phone' => '+966500000209']);
        $ad = $this->makeAd($owner);

        $this->actingAs($stranger)
            ->postJson("/api/v1/ads/{$ad->id}/refresh")
            ->assertForbidden();
    }

    public function test_editing_an_ad_does_not_reset_its_cooldown(): void
    {
        $owner = User::factory()->create(['phone' => '+966500000210']);
        $ad = $this->makeAd($owner);

        $this->actingAs($owner)->postJson("/api/v1/ads/{$ad->id}/refresh")->assertOk();

        $this->travel(1)->hours();

        app(AdService::class)->update($ad, ['title' => 'سيارة للبيع — محدّث']);

        $this->actingAs($owner)
            ->postJson("/api/v1/ads/{$ad->id}/refresh")
            ->assertStatus(422);
    }
}
