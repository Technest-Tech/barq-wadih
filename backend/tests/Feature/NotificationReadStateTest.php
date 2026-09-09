<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Opening the thing a notification points at has to clear it. The client only
 * ever knows the subject — a conversation id, an ad id — so the filtering all
 * happens here.
 */
class NotificationReadStateTest extends TestCase
{
    use RefreshDatabase;

    private function makeNotification(User $user, string $type, array $data): Notification
    {
        return Notification::create([
            'user_id'  => $user->id,
            'type'     => $type,
            'title_ar' => 'عنوان',
            'body_ar'  => 'نص',
            'data'     => $data,
            'channel'  => 'both',
            'sent_at'  => now(),
        ]);
    }

    public function test_it_clears_only_the_notifications_of_one_conversation(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $target = $this->makeNotification($user, 'new_message', [
            'type' => 'chat', 'conversation_id' => 'ad7_u1_u2',
        ]);
        $otherChat = $this->makeNotification($user, 'new_message', [
            'type' => 'chat', 'conversation_id' => 'ad9_u1_u3',
        ]);
        $unrelated = $this->makeNotification($user, 'sale_fee', [
            'type' => 'sale_fee', 'ad_id' => 7,
        ]);

        $this->postJson('/api/v1/notifications/read-by', [
            'type'            => 'new_message',
            'conversation_id' => 'ad7_u1_u2',
        ])->assertOk()->assertJsonPath('data.updated', 1);

        $this->assertTrue($target->fresh()->is_read);
        $this->assertNotNull($target->fresh()->read_at);
        $this->assertFalse($otherChat->fresh()->is_read);
        $this->assertFalse($unrelated->fresh()->is_read);
    }

    public function test_it_matches_an_ad_id_stored_as_either_int_or_string(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // SendSaleFeeNotificationJob writes an int, the commission jobs a
        // string. Both have to clear.
        $asInt = $this->makeNotification($user, 'sale_fee', ['ad_id' => 42]);
        $asString = $this->makeNotification($user, 'commission_rejected', ['ad_id' => '42']);
        $otherAd = $this->makeNotification($user, 'sale_fee', ['ad_id' => 43]);

        $this->postJson('/api/v1/notifications/read-by', ['ad_id' => 42])
            ->assertOk()
            ->assertJsonPath('data.updated', 2);

        $this->assertTrue($asInt->fresh()->is_read);
        $this->assertTrue($asString->fresh()->is_read);
        $this->assertFalse($otherAd->fresh()->is_read);
    }

    public function test_it_never_touches_another_users_notifications(): void
    {
        $mine = User::factory()->create();
        $theirs = User::factory()->create();
        $hers = $this->makeNotification($theirs, 'new_message', [
            'conversation_id' => 'ad7_u1_u2',
        ]);

        Sanctum::actingAs($mine);

        $this->postJson('/api/v1/notifications/read-by', [
            'conversation_id' => 'ad7_u1_u2',
        ])->assertOk()->assertJsonPath('data.updated', 0);

        $this->assertFalse($hers->fresh()->is_read);
    }

    public function test_it_rejects_a_filterless_request(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/notifications/read-by', [])->assertStatus(422);
    }

    public function test_unread_count_drops_after_clearing_a_conversation(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->makeNotification($user, 'new_message', ['conversation_id' => 'ad7_u1_u2']);
        $this->makeNotification($user, 'new_rating', ['ad_id' => 7]);

        $this->getJson('/api/v1/notifications/unread-count')
            ->assertOk()
            ->assertJsonPath('data.count', 2);

        $this->postJson('/api/v1/notifications/read-by', [
            'conversation_id' => 'ad7_u1_u2',
        ])->assertOk();

        $this->getJson('/api/v1/notifications/unread-count')
            ->assertOk()
            ->assertJsonPath('data.count', 1);
    }
}
