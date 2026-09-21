<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Rating;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Profile-level seller reviews, and the super-admin verification badge that a
 * seller receives once they have paid for it.
 */
class SellerReviewAndVerificationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['scout.driver' => null]);
        Queue::fake();
    }

    // ── Profile reviews ──────────────────────────────────────────────────────

    public function test_a_buyer_can_review_a_seller_from_their_profile(): void
    {
        $seller = User::factory()->create();
        $buyer  = User::factory()->create();

        Sanctum::actingAs($buyer);

        $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 4,
            'comment'         => 'بائع محترم والتعامل ممتاز',
            'pledge_accepted' => true,
        ])->assertCreated()
            ->assertJsonPath('data.stars', 4)
            ->assertJsonPath('data.comment', 'بائع محترم والتعامل ممتاز');

        $this->assertDatabaseHas('ratings', [
            'rater_id'      => $buyer->id,
            'rated_user_id' => $seller->id,
            'ad_id'         => null,
            'stars'         => 4,
        ]);

        // The seller's cached aggregate is recalculated, not left stale.
        $seller->refresh();
        $this->assertSame(1, $seller->rating_count);
        $this->assertSame('4.00', (string) $seller->avg_rating);
    }

    public function test_a_second_profile_review_by_the_same_rater_is_rejected(): void
    {
        $seller = User::factory()->create();
        $buyer  = User::factory()->create();

        Sanctum::actingAs($buyer);

        $payload = ['stars' => 5, 'pledge_accepted' => true];

        $this->postJson("/api/v1/users/{$seller->id}/ratings", $payload)->assertCreated();
        $this->postJson("/api/v1/users/{$seller->id}/ratings", $payload)->assertStatus(409);

        $this->assertSame(1, Rating::where('rated_user_id', $seller->id)->count());
    }

    public function test_a_seller_cannot_review_themselves(): void
    {
        $seller = User::factory()->create();

        Sanctum::actingAs($seller);

        $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 5,
            'pledge_accepted' => true,
        ])->assertStatus(403);
    }

    public function test_a_blocked_rater_cannot_review_the_seller(): void
    {
        $seller = User::factory()->create();
        $buyer  = User::factory()->create();

        UserBlock::create(['blocker_id' => $seller->id, 'blocked_id' => $buyer->id]);

        Sanctum::actingAs($buyer);

        $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 1,
            'pledge_accepted' => true,
        ])->assertStatus(403);
    }

    public function test_the_pledge_is_required(): void
    {
        $seller = User::factory()->create();

        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 5,
            'pledge_accepted' => false,
        ])->assertStatus(422)->assertJsonValidationErrors('pledge_accepted');
    }

    public function test_the_profile_tells_the_viewer_whether_they_may_review(): void
    {
        $seller = User::factory()->create();
        $buyer  = User::factory()->create();

        // Signed out: no review affordance at all.
        $this->getJson("/api/v1/users/{$seller->id}")
            ->assertOk()
            ->assertJsonPath('data.can_review', false)
            ->assertJsonPath('data.my_review', null);

        Sanctum::actingAs($buyer);

        $this->getJson("/api/v1/users/{$seller->id}")
            ->assertOk()
            ->assertJsonPath('data.can_review', true);

        $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 3,
            'comment'         => 'تعامل جيد',
            'pledge_accepted' => true,
        ])->assertCreated();

        // Once written, the form closes and the viewer gets their own review back.
        $this->getJson("/api/v1/users/{$seller->id}")
            ->assertOk()
            ->assertJsonPath('data.can_review', false)
            ->assertJsonPath('data.my_review.stars', 3)
            ->assertJsonPath('data.my_review.comment', 'تعامل جيد');
    }

    public function test_deleting_a_profile_review_frees_the_rater_to_write_another(): void
    {
        $seller = User::factory()->create();
        $buyer  = User::factory()->create();

        Sanctum::actingAs($buyer);

        $created = $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 2,
            'pledge_accepted' => true,
        ])->assertCreated()->json('data.id');

        $this->deleteJson("/api/v1/ratings/{$created}")->assertOk();

        $seller->refresh();
        $this->assertSame(0, $seller->rating_count);

        $this->postJson("/api/v1/users/{$seller->id}/ratings", [
            'stars'           => 5,
            'pledge_accepted' => true,
        ])->assertCreated();
    }

    // ── Verification badge ───────────────────────────────────────────────────

    public function test_a_super_admin_can_grant_the_verification_badge(): void
    {
        $superAdmin = User::factory()->create(['role' => UserRole::SuperAdmin]);
        $seller     = User::factory()->create(['is_verified' => false]);

        Sanctum::actingAs($superAdmin);

        $this->patchJson("/api/v1/admin/users/{$seller->id}/verification", [
            'is_verified' => true,
            'note'        => 'سداد رسوم التوثيق — تحويل بنكي #4417',
        ])->assertOk()->assertJsonPath('data.is_verified', true);

        $seller->refresh();
        $this->assertTrue($seller->is_verified);
        $this->assertNotNull($seller->verified_at);
        $this->assertSame($superAdmin->id, $seller->verified_by);
        $this->assertSame('سداد رسوم التوثيق — تحويل بنكي #4417', $seller->verification_note);
    }

    public function test_revoking_the_badge_clears_the_grant_trail(): void
    {
        $superAdmin = User::factory()->create(['role' => UserRole::SuperAdmin]);
        $seller     = User::factory()->create([
            'is_verified'       => true,
            'verified_at'       => now(),
            'verified_by'       => $superAdmin->id,
            'verification_note' => 'دفعة سابقة',
        ]);

        Sanctum::actingAs($superAdmin);

        $this->patchJson("/api/v1/admin/users/{$seller->id}/verification", [
            'is_verified' => false,
        ])->assertOk()->assertJsonPath('data.is_verified', false);

        $seller->refresh();
        $this->assertFalse($seller->is_verified);
        $this->assertNull($seller->verified_at);
        $this->assertNull($seller->verified_by);
        $this->assertNull($seller->verification_note);
    }

    public function test_a_plain_admin_cannot_grant_the_verification_badge(): void
    {
        $admin  = User::factory()->create(['role' => UserRole::Admin]);
        $seller = User::factory()->create(['is_verified' => false]);

        Sanctum::actingAs($admin);

        $this->patchJson("/api/v1/admin/users/{$seller->id}/verification", [
            'is_verified' => true,
        ])->assertStatus(403);

        $this->assertFalse($seller->refresh()->is_verified);
    }

    public function test_a_regular_user_cannot_reach_the_verification_endpoint(): void
    {
        $seller = User::factory()->create(['is_verified' => false]);

        Sanctum::actingAs(User::factory()->create());

        $this->patchJson("/api/v1/admin/users/{$seller->id}/verification", [
            'is_verified' => true,
        ])->assertStatus(403);
    }

    public function test_the_badge_shows_on_the_public_profile_once_granted(): void
    {
        $superAdmin = User::factory()->create(['role' => UserRole::SuperAdmin]);
        $seller     = User::factory()->create(['is_verified' => false]);

        $this->getJson("/api/v1/users/{$seller->id}")
            ->assertOk()
            ->assertJsonPath('data.is_verified', false);

        Sanctum::actingAs($superAdmin);
        $this->patchJson("/api/v1/admin/users/{$seller->id}/verification", [
            'is_verified' => true,
        ])->assertOk();

        $this->getJson("/api/v1/users/{$seller->id}")
            ->assertOk()
            ->assertJsonPath('data.is_verified', true)
            ->assertJsonMissing(['verified_at' => null]);
    }
}
