<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserDevice;
use App\Services\PushService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Exception\Messaging\NotFound;
use Kreait\Firebase\Messaging\MessageTarget;
use Kreait\Firebase\Messaging\MulticastSendReport;
use Kreait\Firebase\Messaging\SendReport;
use Tests\TestCase;

/**
 * The stale-token cleanup used SendReport::index(), which does not exist in
 * kreait 7. It threw inside the send loop, so every push was logged as
 * fcm.dispatch_failed and any batch after the first was never sent.
 */
class PushServiceTokenCleanupTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_unregistered_tokens_are_deactivated(): void
    {
        $user = User::factory()->create();

        $good = UserDevice::create([
            'user_id' => $user->id, 'fcm_token' => 'good-token',
            'device_type' => 'ios', 'is_active' => true,
        ]);
        $stale = UserDevice::create([
            'user_id' => $user->id, 'fcm_token' => 'stale-token',
            'device_type' => 'ios', 'is_active' => true,
        ]);

        $report = MulticastSendReport::withItems([
            SendReport::success(MessageTarget::with(MessageTarget::TOKEN, 'good-token'), []),
            SendReport::failure(
                MessageTarget::with(MessageTarget::TOKEN, 'stale-token'),
                new NotFound('unregistered'),
            ),
        ]);

        $messaging = \Mockery::mock(Messaging::class);
        $messaging->shouldReceive('sendMulticast')->once()->andReturn($report);
        $this->app->instance(Messaging::class, $messaging);

        $service = $this->app->make(PushService::class);

        $dispatch = new \ReflectionMethod($service, 'dispatchFcm');
        $dispatch->setAccessible(true);
        $dispatch->invoke($service, ['good-token', 'stale-token'], 't', 'b', []);

        $this->assertTrue($good->fresh()->is_active, 'a healthy device must stay active');
        $this->assertFalse($stale->fresh()->is_active, 'an unregistered token must be retired');
    }
}
