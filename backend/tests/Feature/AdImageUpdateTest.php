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

class AdImageUpdateTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'filesystems.default' => 'public',
            'scout.driver' => null,
        ]);
        Storage::fake('public');
        Queue::fake();
    }

    public function test_owner_can_replace_two_old_images_with_four_new_images(): void
    {
        [$owner, $ad, $oldImages] = $this->adWithTwoImages();
        Sanctum::actingAs($owner);

        $response = $this->patchJson("/api/v1/ads/{$ad->id}", [
            'remove_image_ids' => $oldImages->pluck('id')->all(),
            'images' => [
                UploadedFile::fake()->image('one.jpg', 900, 700),
                UploadedFile::fake()->image('two.jpg', 900, 700),
                UploadedFile::fake()->image('three.jpg', 900, 700),
                UploadedFile::fake()->image('four.jpg', 900, 700),
            ],
        ]);

        $response->assertOk()
            ->assertJsonCount(4, 'data.images')
            ->assertJsonPath('data.images.0.sort_order', 0);

        $this->assertSame(4, $ad->images()->count());
        foreach ($oldImages as $oldImage) {
            $this->assertDatabaseMissing('ad_images', ['id' => $oldImage->id]);
        }
    }

    public function test_update_rejects_removing_every_image_without_a_replacement(): void
    {
        [$owner, $ad, $oldImages] = $this->adWithTwoImages();
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/ads/{$ad->id}", [
            'remove_image_ids' => $oldImages->pluck('id')->all(),
        ])->assertUnprocessable()->assertJsonValidationErrors('images');

        $this->assertSame(2, $ad->images()->count());
    }

    /** @return array{0:User,1:Ad,2:\Illuminate\Support\Collection<int, AdImage>} */
    private function adWithTwoImages(): array
    {
        $owner = User::factory()->create();
        $region = Region::create([
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => 'riyadh-image-update',
            'is_active' => true,
        ]);
        $city = City::create([
            'region_id' => $region->id,
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => 'riyadh-image-update-city',
            'is_active' => true,
        ]);
        $category = Category::create([
            'name_ar' => 'اختبار الصور',
            'name_en' => 'Image test',
            'slug' => 'image-update-test',
            'is_active' => true,
        ]);
        $ad = Ad::create([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'city_id' => $city->id,
            'region_id' => $region->id,
            'title' => 'إعلان لاختبار الصور',
            'description' => 'وصف إعلان لاختبار استبدال الصور',
            'price' => 100,
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
        ]);

        $images = collect([
            AdImage::create([
                'ad_id' => $ad->id,
                'image_url' => 'ads/old-one_image.webp',
                'thumbnail_url' => 'ads/old-one_thumbnail.webp',
                'sort_order' => 0,
            ]),
            AdImage::create([
                'ad_id' => $ad->id,
                'image_url' => 'ads/old-two_image.webp',
                'thumbnail_url' => 'ads/old-two_thumbnail.webp',
                'sort_order' => 1,
            ]),
        ]);

        return [$owner, $ad, $images];
    }
}
