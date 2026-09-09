<?php

namespace Tests\Feature;

use App\Contracts\ChatDataEraser;
use App\Enums\AdStatus;
use App\Models\Ad;
use App\Models\Category;
use App\Models\City;
use App\Models\Region;
use App\Models\Report;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserSafetyAndDeletionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['scout.driver' => null]);
        Queue::fake();
        $this->instance(ChatDataEraser::class, new class implements ChatDataEraser
        {
            public function eraseForUser(int $userId): void {}
        });
    }

    private function makeVisibleAd(User $owner, string $title): Ad
    {
        $suffix = Region::count();
        $region = Region::create([
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => "safety-region-{$suffix}",
            'is_active' => true,
        ]);
        $city = City::create([
            'region_id' => $region->id,
            'name_ar' => 'الرياض',
            'name_en' => 'Riyadh',
            'slug' => "safety-city-{$suffix}",
            'is_active' => true,
        ]);
        $category = Category::create([
            'name_ar' => 'اختبار',
            'name_en' => 'Test',
            'slug' => "safety-category-{$suffix}",
            'is_active' => true,
        ]);

        return Ad::create([
            'user_id' => $owner->id,
            'category_id' => $category->id,
            'city_id' => $city->id,
            'region_id' => $region->id,
            'title' => $title,
            'description' => 'وصف الإعلان',
            'price' => 100,
            'status' => AdStatus::Active,
            'published_at' => now(),
            'expires_at' => Ad::nextExpiry(),
        ]);
    }

    public function test_a_user_can_block_list_and_unblock_another_user(): void
    {
        $actor = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($actor);

        $this->postJson("/api/v1/users/{$other->id}/block")
            ->assertOk()
            ->assertJsonPath('data.is_blocked', true);

        $this->assertDatabaseHas('user_blocks', [
            'blocker_id' => $actor->id,
            'blocked_id' => $other->id,
        ]);
        $this->assertDatabaseHas('reports', [
            'reporter_id' => $actor->id,
            'reported_user_id' => $other->id,
            'reason' => 'prohibited_content',
            'status' => 'pending',
        ]);

        $this->getJson('/api/v1/users/blocks')
            ->assertOk()
            ->assertJsonPath('data.user_ids.0', $other->id);

        Sanctum::actingAs($other);
        $this->getJson("/api/v1/users/{$actor->id}/safety")
            ->assertOk()
            ->assertJsonPath('data.is_blocked', false)
            ->assertJsonPath('data.interaction_blocked', true);

        Sanctum::actingAs($actor);
        $this->deleteJson("/api/v1/users/{$other->id}/block")
            ->assertOk()
            ->assertJsonPath('data.is_blocked', false);

        $this->assertDatabaseCount('user_blocks', 0);
    }

    public function test_blocking_a_user_removes_their_ads_from_the_feed(): void
    {
        $actor = User::factory()->create();
        $blockedSeller = User::factory()->create();
        $visibleSeller = User::factory()->create();
        $blockedAd = $this->makeVisibleAd($blockedSeller, 'إعلان المستخدم المحظور');
        $visibleAd = $this->makeVisibleAd($visibleSeller, 'إعلان مستخدم آخر');
        Sanctum::actingAs($actor);

        $before = collect($this->getJson('/api/v1/ads')->assertOk()->json('data'))
            ->pluck('id');
        $this->assertTrue($before->contains($blockedAd->id));
        $this->assertTrue($before->contains($visibleAd->id));

        $this->postJson("/api/v1/users/{$blockedSeller->id}/block", [
            'conversation_id' => 'review-demo-conversation',
        ])->assertOk()
            ->assertJsonPath('data.is_blocked', true)
            ->assertJsonPath('data.report_submitted', true);

        $after = collect($this->getJson('/api/v1/ads')->assertOk()->json('data'))
            ->pluck('id');
        $this->assertFalse($after->contains($blockedAd->id));
        $this->assertTrue($after->contains($visibleAd->id));

        $this->getJson("/api/v1/ads/{$blockedAd->id}")->assertNotFound();
        $this->assertDatabaseHas('reports', [
            'reporter_id' => $actor->id,
            'reported_user_id' => $blockedSeller->id,
            'conversation_id' => 'review-demo-conversation',
            'status' => 'pending',
        ]);
    }

    public function test_a_user_can_report_another_user_for_moderation(): void
    {
        $actor = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($actor);

        $this->postJson("/api/v1/users/{$other->id}/report", [
            'reason' => 'scam_or_fraud',
            'description' => 'طلب تحويل مبلغ خارج المنصة.',
            'conversation_id' => 'conversation-123',
        ])->assertOk();

        $report = Report::firstOrFail();
        $this->assertSame($actor->id, $report->reporter_id);
        $this->assertSame($other->id, $report->reported_user_id);
        $this->assertNull($report->ad_id);
        $this->assertSame('conversation-123', $report->conversation_id);

        $this->postJson("/api/v1/users/{$other->id}/report", [
            'reason' => 'spam',
        ])->assertStatus(409);
    }

    public function test_obviously_abusive_text_is_rejected_before_publication(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/safety/check-content', [
            'text' => 'مرحبا، هل المنتج متاح؟',
        ])->assertOk()->assertJsonPath('data.allowed', true);

        $this->postJson('/api/v1/safety/check-content', [
            'text' => 'fuck you',
        ])->assertUnprocessable()->assertJsonValidationErrors('text');
    }

    public function test_account_deletion_requires_confirmation_and_anonymises_the_user(): void
    {
        $actor = User::factory()->create([
            'name' => 'بيانات شخصية',
            'phone' => '+966500000099',
            'bio' => 'نبذة شخصية',
        ]);
        $other = User::factory()->create();
        $actor->createToken('test-token');
        UserBlock::create(['blocker_id' => $actor->id, 'blocked_id' => $other->id]);
        Sanctum::actingAs($actor);

        $this->deleteJson('/api/v1/auth/account', ['confirmation' => 'WRONG'])
            ->assertUnprocessable();

        $this->deleteJson('/api/v1/auth/account', ['confirmation' => 'DELETE'])
            ->assertOk();

        $deleted = User::withTrashed()->findOrFail($actor->id);
        $this->assertTrue($deleted->trashed());
        $this->assertSame('حساب محذوف', $deleted->name);
        $this->assertNull($deleted->email);
        $this->assertNull($deleted->phone);
        $this->assertNull($deleted->password);
        $this->assertNull($deleted->bio);
        $this->assertFalse($deleted->is_active);
        $this->assertDatabaseMissing('personal_access_tokens', [
            'tokenable_type' => User::class,
            'tokenable_id' => $actor->id,
        ]);
        $this->assertDatabaseMissing('user_blocks', ['blocker_id' => $actor->id]);
    }
}
