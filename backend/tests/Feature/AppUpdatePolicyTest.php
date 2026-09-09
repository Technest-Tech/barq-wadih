<?php

namespace Tests\Feature;

use Tests\TestCase;

class AppUpdatePolicyTest extends TestCase
{
    public function test_unpublished_or_incomplete_releases_are_not_advertised(): void
    {
        config(['app_updates' => [
            'ios' => ['published' => false, 'version' => '2.0', 'minimum_os' => '15'],
            'android' => ['published' => true, 'version' => '2.0', 'build' => 20],
        ]]);
        $this->getJson('/api/v1/app-updates')->assertOk()
            ->assertJsonPath('data.ios', null)->assertJsonPath('data.android', null);
    }

    public function test_published_releases_are_public_and_use_fixed_store_links(): void
    {
        config(['app_updates' => [
            'ios' => ['published' => true, 'version' => '2.0', 'minimum_os' => '15'],
            'android' => ['published' => true, 'version' => '2.0', 'build' => '20', 'minimum_sdk' => '24'],
        ]]);
        $this->getJson('/api/v1/app-updates')->assertOk()
            ->assertJsonPath('data.ios.version', '2.0')
            ->assertJsonPath('data.ios.store_url', 'https://apps.apple.com/app/id6800784915')
            ->assertJsonPath('data.android.build', 20)
            ->assertJsonPath('data.android.minimum_sdk', 24);
    }

    public function test_malformed_version_and_compatibility_values_fail_closed(): void
    {
        config(['app_updates' => [
            'ios' => ['published' => true, 'version' => '2.0', 'minimum_os' => 'invalid'],
            'android' => ['published' => true, 'version' => '2.0-beta', 'build' => 20, 'minimum_sdk' => 24],
        ]]);
        $this->getJson('/api/v1/app-updates')->assertOk()
            ->assertJsonPath('data.ios', null)->assertJsonPath('data.android', null);
    }
}
