<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\SnapchatConversionsService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SnapchatConversionsServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_tracking_endpoint_accepts_a_valid_guest_event(): void
    {
        config()->set('services.snapchat.app_id', 'snap-app-id');
        config()->set('services.snapchat.capi_token', 'secret-token');
        Http::fake(['tr.snapchat.com/*' => Http::response(['status' => 'VALID'])]);

        $this->postJson('/api/v1/tracking/events', $this->event())
            ->assertStatus(202);

        Http::assertSentCount(1);
        Http::assertSent(function (Request $request): bool {
            $extinfo = $request->data()['data'][0]['app_data']['extinfo'];

            return count($extinfo) === 16
                && collect($extinfo)->every(static fn (mixed $value): bool => $value === '');
        });
    }

    public function test_it_hashes_matching_data_and_builds_a_mobile_app_event(): void
    {
        config()->set('services.snapchat.app_id', 'snap-app-id');
        config()->set('services.snapchat.capi_token', 'secret-token');
        config()->set('services.snapchat.endpoint', 'https://tr.snapchat.com/v3');
        config()->set('services.snapchat.event_source_url', 'https://barqwadih.com/app');
        Http::fake(['tr.snapchat.com/*' => Http::response(['status' => 'VALID'])]);

        $user = User::factory()->create([
            'email' => 'Person@Example.com',
            'phone' => '0501234567',
        ]);

        $sent = app(SnapchatConversionsService::class)->send(
            event: $this->event(),
            user: $user,
            clientIp: '203.0.113.10',
            clientUserAgent: 'BarqWadih/1.0',
        );

        $this->assertTrue($sent);
        Http::assertSent(function (Request $request) use ($user): bool {
            $event = $request->data()['data'][0];

            return $request->url() === 'https://tr.snapchat.com/v3/snap-app-id/events?access_token=secret-token'
                && $event['action_source'] === 'MOBILE_APP'
                && ! isset($event['integration'])
                && $event['event_name'] === 'SIGN_UP'
                && $event['app_data']['app_id'] === 'com.barqwadih.barq_wadih'
                && $event['user_data']['em'] === hash('sha256', 'person@example.com')
                && $event['user_data']['ph'] === hash('sha256', '966501234567')
                && $event['user_data']['external_id'] === hash('sha256', (string) $user->id)
                && ! isset($event['user_data']['anon_id']);
        });
    }

    public function test_it_omits_account_matching_data_when_tracking_is_disabled(): void
    {
        config()->set('services.snapchat.app_id', 'snap-app-id');
        config()->set('services.snapchat.capi_token', 'secret-token');
        Http::fake(['tr.snapchat.com/*' => Http::response(['status' => 'VALID'])]);
        $event = $this->event();
        $event['app_data']['advertiser_tracking_enabled'] = false;

        app(SnapchatConversionsService::class)->send(
            event: $event,
            user: User::factory()->create(),
            clientIp: '203.0.113.10',
            clientUserAgent: 'BarqWadih/1.0',
        );

        Http::assertSent(function (Request $request): bool {
            $userData = $request->data()['data'][0]['user_data'];

            return ! isset($userData['em'], $userData['ph'], $userData['external_id'], $userData['anon_id'])
                && $userData['client_ip_address'] === '203.0.113.10';
        });
    }

    public function test_it_does_not_treat_a_non_valid_snap_response_as_accepted(): void
    {
        config()->set('services.snapchat.app_id', 'snap-app-id');
        config()->set('services.snapchat.capi_token', 'secret-token');
        Http::fake(['tr.snapchat.com/*' => Http::response([
            'status' => 'INVALID',
            'errors' => [
                'codes' => ['507'],
                'error_msgs' => ['Insufficient customer information.'],
            ],
        ], 200)]);

        $sent = app(SnapchatConversionsService::class)->send(
            event: $this->event(),
            user: null,
            clientIp: '203.0.113.10',
            clientUserAgent: 'BarqWadih/1.0',
        );

        $this->assertFalse($sent);
    }

    private function event(): array
    {
        return [
            'event_name' => 'SIGN_UP',
            'event_time' => 1787735657000,
            'event_id' => 'event-123',
            'app_data' => [
                'app_id' => 'com.barqwadih.barq_wadih',
                'advertiser_tracking_enabled' => true,
                'extinfo' => array_fill(0, 16, ''),
            ],
            'custom_data' => ['status' => 'new'],
        ];
    }
}
