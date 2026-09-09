<?php

namespace Tests\Feature;

use App\Enums\CampaignStatus;
use App\Jobs\SendCampaignJob;
use App\Models\Notification;
use App\Models\NotificationCampaign;
use App\Models\User;
use App\Models\UserDevice;
use App\Services\CampaignSender;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\MessageTarget;
use Kreait\Firebase\Messaging\MulticastSendReport;
use Kreait\Firebase\Messaging\SendReport;
use Tests\TestCase;

/**
 * Admin broadcast / direct messages.
 *
 * The old send path only inserted rows into `notifications` — it never called
 * PushService, so no device ever rang. These lock in that delivery actually
 * reaches FCM and that targeting picks the right people.
 */
class AdminCampaignDeliveryTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['role' => 'admin', 'is_active' => true]);
    }

    /** Swap FCM for a mock that reports success for every token it is given. */
    private function fakeMessaging(): \Mockery\MockInterface
    {
        $messaging = \Mockery::mock(Messaging::class);
        $messaging->shouldReceive('sendMulticast')->andReturnUsing(
            fn ($message, $tokens) => MulticastSendReport::withItems(
                collect($tokens)->map(fn ($t) => SendReport::success(
                    MessageTarget::with(MessageTarget::TOKEN, $t), []
                ))->all()
            )
        );
        $this->app->instance(Messaging::class, $messaging);

        return $messaging;
    }

    public function test_a_broadcast_writes_an_in_app_row_and_pushes_to_devices(): void
    {
        $this->fakeMessaging();

        $admin      = $this->admin();
        $withDevice = User::factory()->create(['is_active' => true]);
        $noDevice   = User::factory()->create(['is_active' => true]);
        $suspended  = User::factory()->create(['is_active' => false]);

        UserDevice::create([
            'user_id' => $withDevice->id, 'fcm_token' => 'token-a',
            'device_type' => 'ios', 'is_active' => true,
        ]);

        $campaign = NotificationCampaign::create([
            'admin_id' => $admin->id,
            'title_ar' => 'تحديث المنصة',
            'body_ar' => 'أضفنا ميزة جديدة',
            'target_type' => 'all',
            'status' => CampaignStatus::Draft->value,
        ]);

        $total = $this->app->make(CampaignSender::class)->deliver($campaign);

        // Every active account, the sending admin included; suspended ones out.
        $this->assertSame(3, $total, 'only active users are in the audience');

        foreach ([$withDevice, $noDevice] as $user) {
            $this->assertDatabaseHas('notifications', [
                'user_id' => $user->id,
                'type' => 'campaign',
                'title_ar' => 'تحديث المنصة',
            ]);
        }
        $this->assertDatabaseMissing('notifications', ['user_id' => $suspended->id]);

        $campaign->refresh();
        $this->assertSame(CampaignStatus::Sent, $campaign->status);
        $this->assertSame(3, $campaign->recipients_count);
        $this->assertSame(1, $campaign->delivered_count, 'only one user had a device to push to');
    }

    public function test_a_direct_message_reaches_only_the_chosen_user(): void
    {
        $this->fakeMessaging();

        $target = User::factory()->create(['is_active' => true]);
        $other  = User::factory()->create(['is_active' => true]);

        $campaign = NotificationCampaign::create([
            'admin_id' => $this->admin()->id,
            'title_ar' => 'بخصوص إعلانك',
            'body_ar' => 'يرجى تعديل الوصف',
            'target_type' => 'specific_users',
            'target_user_ids' => [$target->id],
            'status' => CampaignStatus::Draft->value,
        ]);

        $this->app->make(CampaignSender::class)->deliver($campaign);

        $this->assertSame(1, Notification::where('user_id', $target->id)->count());
        $this->assertSame(0, Notification::where('user_id', $other->id)->count());
    }

    public function test_send_now_endpoint_queues_delivery(): void
    {
        Queue::fake();

        $recipient = User::factory()->create(['is_active' => true]);

        $response = $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/v1/admin/notifications/send', [
                'title_ar' => 'رسالة إدارية',
                'body_ar' => 'نص الرسالة',
                'target_type' => 'specific_users',
                'target_user_ids' => [$recipient->id],
            ]);

        $response->assertCreated()->assertJsonPath('data.recipients_count', 1);

        Queue::assertPushed(SendCampaignJob::class);
        $this->assertDatabaseHas('notification_campaigns', ['title_ar' => 'رسالة إدارية']);
    }

    public function test_send_now_refuses_an_empty_audience(): void
    {
        Queue::fake();

        $suspended = User::factory()->create(['is_active' => false]);

        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/v1/admin/notifications/send', [
                'title_ar' => 'رسالة',
                'body_ar' => 'نص',
                'target_type' => 'specific_users',
                'target_user_ids' => [$suspended->id],
            ])
            ->assertStatus(422);

        Queue::assertNothingPushed();
        // The throwaway draft must not linger in the campaign list.
        $this->assertDatabaseCount('notification_campaigns', 0);
    }

    public function test_specific_users_targeting_requires_ids(): void
    {
        $this->actingAs($this->admin(), 'sanctum')
            ->postJson('/api/v1/admin/notifications/send', [
                'title_ar' => 'رسالة',
                'body_ar' => 'نص',
                'target_type' => 'specific_users',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('target_user_ids');
    }
}
