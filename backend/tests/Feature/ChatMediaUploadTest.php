<?php

namespace Tests\Feature;

use App\Enums\AdStatus;
use App\Models\Ad;
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

class ChatMediaUploadTest extends TestCase
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

    public function test_a_participant_can_upload_a_chat_image(): void
    {
        [$seller, $buyer, $ad, $conversationId] = $this->conversation();
        Sanctum::actingAs($buyer);

        $this->postJson("/api/v1/chat/conversations/{$conversationId}/media", [
            'type' => 'image',
            'file' => UploadedFile::fake()->image('chat.jpg', 1200, 800),
        ])->assertOk()
            ->assertJsonPath('data.type', 'image')
            ->assertJsonPath('data.mime_type', 'image/webp')
            ->assertJsonStructure(['data' => ['url', 'thumbnail_url', 'size']]);

        $this->assertCount(
            2,
            Storage::disk('public')->allFiles("chat/{$conversationId}/images"),
        );
    }

    public function test_a_participant_can_upload_a_voice_note(): void
    {
        [$seller, $buyer, $ad, $conversationId] = $this->conversation();
        Sanctum::actingAs($seller);

        $this->postJson("/api/v1/chat/conversations/{$conversationId}/media", [
            'type' => 'voice',
            'file' => UploadedFile::fake()->create('note.m4a', 128, 'audio/mp4'),
        ])->assertOk()
            ->assertJsonPath('data.type', 'voice')
            ->assertJsonStructure(['data' => ['url', 'mime_type', 'size']]);

        $this->assertCount(
            1,
            Storage::disk('public')->allFiles("chat/{$conversationId}/voice"),
        );
    }

    public function test_a_non_participant_cannot_upload_chat_media(): void
    {
        [$seller, $buyer, $ad, $conversationId] = $this->conversation();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/chat/conversations/{$conversationId}/media", [
            'type' => 'voice',
            'file' => UploadedFile::fake()->create('note.m4a', 32, 'audio/mp4'),
        ])->assertForbidden();

        $this->assertSame([], Storage::disk('public')->allFiles('chat'));
    }

    public function test_chat_media_rejects_an_unsupported_file_type(): void
    {
        [$seller, $buyer, $ad, $conversationId] = $this->conversation();
        Sanctum::actingAs($buyer);

        $this->postJson("/api/v1/chat/conversations/{$conversationId}/media", [
            'type' => 'image',
            'file' => UploadedFile::fake()->create('payload.pdf', 32, 'application/pdf'),
        ])->assertUnprocessable()->assertJsonValidationErrors('file');
    }

    /**
     * @return array{0:User,1:User,2:Ad,3:string}
     */
    private function conversation(): array
    {
        $seller = User::factory()->create();
        $buyer = User::factory()->create();

        $region = Region::create([
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => 'riyadh-chat',
            'is_active' => true,
        ]);
        $city = City::create([
            'region_id' => $region->id,
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => 'riyadh-chat-city',
            'is_active' => true,
        ]);
        $category = Category::create([
            'name_ar' => 'اختبار',
            'name_en' => 'Test',
            'slug' => 'chat-media-test',
            'is_active' => true,
        ]);

        $ad = Ad::create([
            'user_id' => $seller->id,
            'category_id' => $category->id,
            'city_id' => $city->id,
            'region_id' => $region->id,
            'title' => 'إعلان اختبار المحادثة',
            'description' => 'وصف للاختبار',
            'price' => 100,
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
        ]);

        $ids = [$seller->id, $buyer->id];
        sort($ids);

        return [
            $seller,
            $buyer,
            $ad,
            "ad{$ad->id}_u{$ids[0]}_u{$ids[1]}",
        ];
    }
}
