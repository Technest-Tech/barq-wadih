<?php

namespace Tests\Feature;

use App\Enums\AdStatus;
use App\Models\Ad;
use App\Models\AdFieldValue;
use App\Models\AdImage;
use App\Models\Category;
use App\Models\CategoryField;
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
 * Edits a seller makes must actually land. UpdateAdRequest lists every rule as
 * `sometimes`, so any field missing from it is dropped by validated() in
 * silence and the endpoint still answers "تم تحديث الإعلان بنجاح" — the shape
 * of bug these tests exist to catch.
 */
class AdUpdateTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['filesystems.default' => 'public', 'scout.driver' => null]);
        Storage::fake('public');
        Queue::fake();
    }

    public function test_owner_can_switch_an_ad_to_call_for_price(): void
    {
        [$owner, $ad] = $this->activeAd();
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'price_hidden' => true,
            'is_negotiable' => false,
        ])->assertOk();

        $this->assertTrue($ad->fresh()->price_hidden);
    }

    public function test_owner_can_switch_an_ad_back_to_a_visible_price(): void
    {
        [$owner, $ad] = $this->activeAd();
        $ad->update(['price_hidden' => true]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'price' => 4500,
            'price_hidden' => false,
        ])->assertOk();

        $fresh = $ad->fresh();
        $this->assertFalse($fresh->price_hidden);
        $this->assertEquals(4500, $fresh->price);
    }

    public function test_owner_can_mark_an_ad_free(): void
    {
        [$owner, $ad] = $this->activeAd();
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", ['is_free' => true])->assertOk();

        $this->assertTrue($ad->fresh()->is_free);
    }

    public function test_owner_can_edit_the_written_details_of_an_ad(): void
    {
        [$owner, $ad] = $this->activeAd();
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'title' => 'عنوان بعد التعديل',
            'description' => 'وصف جديد تماماً بعد تعديل الإعلان من التطبيق',
            'contact_phone' => '0501234567',
            'show_phone_publicly' => false,
        ])->assertOk();

        $fresh = $ad->fresh();
        $this->assertSame('عنوان بعد التعديل', $fresh->title);
        $this->assertSame('وصف جديد تماماً بعد تعديل الإعلان من التطبيق', $fresh->description);
        $this->assertSame('0501234567', $fresh->contact_phone);
        $this->assertFalse($fresh->show_phone_publicly);
    }

    /**
     * The app posts the contact field on every edit, so a seller who never
     * filled it sends an empty string that Laravel converts to null. That null
     * used to fail the `string` rule and block the whole edit — an optional
     * field behaving as if it were required.
     */
    public function test_owner_can_save_an_edit_with_a_blank_phone_when_it_is_not_public(): void
    {
        [$owner, $ad] = $this->activeAd();
        $ad->update(['show_phone_publicly' => false]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'title' => 'عنوان بعد التعديل',
            'contact_phone' => null,
            'show_phone_publicly' => false,
        ])->assertOk();

        $fresh = $ad->fresh();
        $this->assertSame('عنوان بعد التعديل', $fresh->title);
        $this->assertNull($fresh->contact_phone);
    }

    /**
     * The exact payload the app sends: a multipart edit carrying an empty
     * contact field for a seller who never entered a number.
     */
    public function test_owner_can_save_an_edit_with_an_empty_phone_string(): void
    {
        [$owner, $ad] = $this->activeAd();
        $ad->update(['show_phone_publicly' => false]);
        Sanctum::actingAs($owner);

        $this->patch("/api/v1/ads/{$ad->id}", [
            'title' => 'عنوان بعد التعديل',
            'contact_phone' => '',
            'show_phone_publicly' => '0',
        ], ['Accept' => 'application/json'])->assertOk();

        $this->assertNull($ad->fresh()->contact_phone);
    }

    public function test_clearing_the_phone_is_rejected_while_the_ad_shows_it_publicly(): void
    {
        [$owner, $ad] = $this->activeAd();
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'contact_phone' => null,
            'show_phone_publicly' => true,
        ])->assertStatus(422)->assertJsonValidationErrors('contact_phone');

        $this->assertSame('0555555555', $ad->fresh()->contact_phone);
    }

    /**
     * A client that clears the phone without resending the visibility flag has
     * to be judged against the ad as it stands, not against an absent flag.
     */
    public function test_clearing_the_phone_is_rejected_when_the_ad_is_already_public_and_the_flag_is_omitted(): void
    {
        [$owner, $ad] = $this->activeAd();
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'contact_phone' => null,
        ])->assertStatus(422)->assertJsonValidationErrors('contact_phone');
    }

    // ── Category switching ────────────────────────────────────────────────

    public function test_changing_category_clears_the_old_categorys_field_values(): void
    {
        [$owner, $ad] = $this->activeAd();
        $oldField = CategoryField::create([
            'category_id' => $ad->category_id,
            'field_key' => 'mileage',
            'label_ar' => 'الممشى',
            'label_en' => 'Mileage',
            'field_type' => 'number',
            'is_required' => false,
        ]);
        AdFieldValue::create([
            'ad_id' => $ad->id,
            'category_field_id' => $oldField->id,
            'value' => '120000',
        ]);

        $target = Category::create([
            'name_ar' => 'أثاث', 'name_en' => 'Furniture',
            'slug' => 'furniture-target', 'is_active' => true,
        ]);
        CategoryField::create([
            'category_id' => $target->id,
            'field_key' => 'material',
            'label_ar' => 'الخامة',
            'label_en' => 'Material',
            'field_type' => 'text',
            'is_required' => true,
        ]);

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'category_id' => $target->id,
            'fields' => ['material' => 'خشب'],
        ])->assertOk();

        $fresh = $ad->fresh(['fieldValues']);
        $this->assertSame($target->id, $fresh->category_id);
        $this->assertCount(1, $fresh->fieldValues);
        $this->assertSame('خشب', $fresh->fieldValues->first()->value);
        $this->assertDatabaseMissing('ad_field_values', [
            'ad_id' => $ad->id,
            'category_field_id' => $oldField->id,
        ]);
    }

    public function test_changing_category_requires_the_new_categorys_required_fields(): void
    {
        [$owner, $ad] = $this->activeAd();
        $target = Category::create([
            'name_ar' => 'سيارات', 'name_en' => 'Cars',
            'slug' => 'cars-target', 'is_active' => true,
        ]);
        CategoryField::create([
            'category_id' => $target->id,
            'field_key' => 'model_year',
            'label_ar' => 'سنة الصنع',
            'label_en' => 'Model year',
            'field_type' => 'number',
            'is_required' => true,
        ]);

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", ['category_id' => $target->id])
            ->assertStatus(422)
            ->assertJsonValidationErrors('fields.model_year');

        $this->assertNotSame($target->id, $ad->fresh()->category_id);
    }

    public function test_a_parent_category_is_rejected(): void
    {
        [$owner, $ad] = $this->activeAd();
        $parent = Category::create([
            'name_ar' => 'رئيسي', 'name_en' => 'Parent',
            'slug' => 'parent-target', 'is_active' => true,
        ]);
        Category::create([
            'name_ar' => 'فرعي', 'name_en' => 'Child',
            'slug' => 'child-target', 'parent_id' => $parent->id, 'is_active' => true,
        ]);

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", ['category_id' => $parent->id])
            ->assertStatus(422)
            ->assertJsonValidationErrors('category_id');
    }

    // ── Image ordering ────────────────────────────────────────────────────

    public function test_owner_can_reorder_images_to_pick_a_new_cover(): void
    {
        [$owner, $ad] = $this->activeAd();
        $second = AdImage::create([
            'ad_id' => $ad->id,
            'image_url' => 'ads/two_image.webp',
            'thumbnail_url' => 'ads/two_thumbnail.webp',
            'sort_order' => 1,
        ]);
        $third = AdImage::create([
            'ad_id' => $ad->id,
            'image_url' => 'ads/three_image.webp',
            'thumbnail_url' => 'ads/three_thumbnail.webp',
            'sort_order' => 2,
        ]);
        $first = $ad->images()->orderBy('sort_order')->first();

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'image_order' => [$third->id, $first->id, $second->id],
        ])->assertOk()->assertJsonPath('data.images.0.id', $third->id);

        $this->assertSame(
            [$third->id, $first->id, $second->id],
            $ad->fresh()->images()->orderBy('sort_order')->pluck('id')->all(),
        );
        $this->assertSame(0, $ad->fresh()->images()->orderBy('sort_order')->first()->sort_order);
    }

    public function test_removing_the_cover_promotes_the_next_image(): void
    {
        [$owner, $ad] = $this->activeAd();
        $second = AdImage::create([
            'ad_id' => $ad->id,
            'image_url' => 'ads/two_image.webp',
            'thumbnail_url' => 'ads/two_thumbnail.webp',
            'sort_order' => 1,
        ]);
        $cover = $ad->images()->orderBy('sort_order')->first();

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'remove_image_ids' => [$cover->id],
        ])->assertOk();

        // Without re-sequencing the survivor keeps sort_order 1 and the ad has
        // no image at position 0 to act as its cover.
        $survivor = $ad->fresh()->images()->orderBy('sort_order')->first();
        $this->assertSame($second->id, $survivor->id);
        $this->assertSame(0, $survivor->sort_order);
    }

    public function test_a_photo_added_during_the_edit_can_become_the_cover(): void
    {
        [$owner, $ad] = $this->activeAd();
        $existing = $ad->images()->first();

        Sanctum::actingAs($owner);
        $response = $this->patchJson("/api/v1/ads/{$ad->id}", [
            'images' => [UploadedFile::fake()->image('fresh.jpg', 900, 700)],
            // "new:0" is the first (only) upload in this request.
            'image_order' => ['new:0', (string) $existing->id],
        ])->assertOk();

        $ordered = $ad->fresh()->images()->orderBy('sort_order')->get();
        $this->assertCount(2, $ordered);
        $this->assertNotSame($existing->id, $ordered->first()->id);
        $this->assertSame(0, $ordered->first()->sort_order);
        $this->assertSame($existing->id, $ordered->last()->id);
        $response->assertJsonPath('data.images.0.id', $ordered->first()->id);
    }

    public function test_image_order_rejects_an_upload_index_that_was_not_sent(): void
    {
        [$owner, $ad] = $this->activeAd();

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", ['image_order' => ['new:3']])
            ->assertStatus(422)
            ->assertJsonValidationErrors('image_order');
    }

    public function test_reordering_rejects_an_image_from_another_ad(): void
    {
        [$owner, $ad] = $this->activeAd();
        [, $otherAd] = $this->activeAd('second');
        $foreign = $otherAd->images()->first();

        Sanctum::actingAs($owner);
        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'image_order' => [$foreign->id],
        ])->assertStatus(422)->assertJsonValidationErrors('image_order');
    }

    /** @return array{0: User, 1: Ad} */
    private function activeAd(string $suffix = 'first'): array
    {
        $owner = User::factory()->create();
        $region = Region::create([
            'name_ar' => 'الرياض', 'name_en' => 'Riyadh',
            'slug' => "riyadh-ad-update-{$suffix}", 'is_active' => true,
        ]);
        $city = City::create([
            'region_id' => $region->id, 'name_ar' => 'الرياض',
            'name_en' => 'Riyadh', 'slug' => "riyadh-ad-update-city-{$suffix}", 'is_active' => true,
        ]);
        $category = Category::create([
            'name_ar' => 'اختبار التعديل', 'name_en' => 'Update test',
            'slug' => "ad-update-test-{$suffix}", 'is_active' => true,
        ]);
        $ad = Ad::create([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'city_id' => $city->id,
            'region_id' => $region->id,
            'title' => 'إعلان قبل التعديل',
            'description' => 'وصف الإعلان قبل أي تعديل من البائع',
            'price' => 100,
            'contact_phone' => '0555555555',
            'show_phone_publicly' => true,
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
        ]);
        AdImage::create([
            'ad_id' => $ad->id,
            'image_url' => 'ads/one_image.webp',
            'thumbnail_url' => 'ads/one_thumbnail.webp',
            'sort_order' => 0,
        ]);

        return [$owner, $ad];
    }
}
