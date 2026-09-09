<?php

namespace Tests\Feature;

use App\Enums\AdStatus;
use App\Models\Ad;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * "على السوم" invites offers instead of naming a price, so 0 is a legitimate
 * entry there — min:1 rejected it and the seller could not publish at all.
 * A zero price is stored as null, which is the state price-less ads already
 * use for display and sorting. A fixed price of 0 stays invalid: a giveaway
 * is is_free, not a price of zero.
 */
class NegotiablePriceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['filesystems.default' => 'public', 'scout.driver' => null]);
        Storage::fake('public');
        Queue::fake();
    }

    // ── Publishing ────────────────────────────────────────────────────────────

    public function test_seller_can_publish_an_ala_alsoom_ad_priced_at_zero(): void
    {
        $user = $this->seller();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/ads', $this->publishPayload([
            'is_negotiable' => '1',
            'price' => '0',
        ]))->assertCreated();

        $ad = Ad::findOrFail($response->json('data.ad.id'));
        $this->assertTrue($ad->is_negotiable);
        $this->assertNull($ad->price, 'a 0 asking price is stored as no price');
    }

    public function test_an_ala_alsoom_ad_keeps_a_real_asking_price(): void
    {
        $user = $this->seller();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/ads', $this->publishPayload([
            'is_negotiable' => '1',
            'price' => '4500',
        ]))->assertCreated();

        $ad = Ad::findOrFail($response->json('data.ad.id'));
        $this->assertTrue($ad->is_negotiable);
        $this->assertEquals(4500, $ad->price);
    }

    public function test_a_fixed_price_ad_still_cannot_be_published_at_zero(): void
    {
        $user = $this->seller();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/ads', $this->publishPayload([
            'is_negotiable' => '0',
            'price' => '0',
        ]))->assertUnprocessable()->assertJsonValidationErrors('price');
    }

    // ── Editing ───────────────────────────────────────────────────────────────

    public function test_owner_can_edit_an_ala_alsoom_ad_down_to_zero(): void
    {
        [$owner, $ad] = $this->existingAd(['is_negotiable' => true, 'price' => 3000]);
        Sanctum::actingAs($owner);

        // The wizard sends only what changed, so is_negotiable is absent here —
        // the rule has to fall back to the flag already on the ad.
        $this->patchJson("/api/v1/ads/{$ad->id}", ['price' => 0])->assertOk();

        $this->assertNull($ad->fresh()->price);
    }

    public function test_owner_cannot_edit_a_fixed_price_ad_down_to_zero(): void
    {
        [$owner, $ad] = $this->existingAd(['is_negotiable' => false, 'price' => 3000]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", ['price' => 0])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('price');

        $this->assertEquals(3000, $ad->fresh()->price);
    }

    public function test_switching_an_ad_to_ala_alsoom_at_zero_in_one_edit(): void
    {
        [$owner, $ad] = $this->existingAd(['is_negotiable' => false, 'price' => 3000]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'price' => 0,
            'is_negotiable' => true,
        ])->assertOk();

        $fresh = $ad->fresh();
        $this->assertTrue($fresh->is_negotiable);
        $this->assertNull($fresh->price);
    }

    // ── Fixtures ──────────────────────────────────────────────────────────────

    private function seller(): User
    {
        return User::factory()->create(['is_dealer' => false]);
    }

    /** @return array<string, mixed> */
    private function publishPayload(array $overrides = []): array
    {
        return array_merge([
            'category_id' => $this->category()->id,
            'city_id' => $this->city()->id,
            'title' => 'جهاز للبيع',
            'description' => 'وصف كافٍ للإعلان المنشور في الاختبار',
            'price' => '1000',
            'is_negotiable' => '0',
            'price_hidden' => '0',
            'show_phone_publicly' => '0',
            'pledge_accepted' => '1',
            'images' => [UploadedFile::fake()->image('one.jpg', 900, 700)],
        ], $overrides);
    }

    /** @return array{0: User, 1: Ad} */
    private function existingAd(array $attributes = []): array
    {
        $owner = $this->seller();
        $ad = Ad::create(array_merge([
            'user_id' => $owner->id,
            'category_id' => $this->category()->id,
            'city_id' => $this->city()->id,
            'region_id' => $this->city()->region_id,
            'title' => 'إعلان قبل التعديل',
            'description' => 'وصف الإعلان قبل أي تعديل من البائع',
            'price' => 100,
            'show_phone_publicly' => false,
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
        ], $attributes));
        AdImage::create([
            'ad_id' => $ad->id,
            'image_url' => 'ads/one_image.webp',
            'thumbnail_url' => 'ads/one_thumbnail.webp',
            'sort_order' => 0,
        ]);

        return [$owner, $ad];
    }

    private function city(): City
    {
        return City::firstOrCreate(
            ['slug' => 'riyadh-negotiable-price'],
            [
                'region_id' => Region::firstOrCreate(
                    ['slug' => 'riyadh-negotiable-price'],
                    ['name_ar' => 'الرياض', 'name_en' => 'Riyadh', 'is_active' => true],
                )->id,
                'name_ar' => 'الرياض',
                'name_en' => 'Riyadh',
                'is_active' => true,
            ],
        );
    }

    private function category(): Category
    {
        return Category::firstOrCreate(
            ['slug' => 'negotiable-price-test'],
            ['name_ar' => 'اختبار السوم', 'name_en' => 'Negotiable test', 'is_active' => true],
        );
    }
}
