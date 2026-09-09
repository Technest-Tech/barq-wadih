<?php

namespace Tests\Feature;

use App\Contracts\ChatDataEraser;
use App\Models\User;
use App\Services\AuthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Tests\TestCase;

/**
 * Chat signs in to Firebase with strval($user->id) — never `firebase_uid`,
 * which only the legacy phone-OTP path sets. Deleting only `firebase_uid`
 * therefore left every email-only account with a live Firebase identity.
 */
class AccountDeletionFirebaseIdentityTest extends TestCase
{
    use RefreshDatabase;

    /** @var list<string> */
    private array $deleted = [];

    protected function setUp(): void
    {
        parent::setUp();
        config(['scout.driver' => null]);
        Queue::fake();

        $this->instance(ChatDataEraser::class, new class implements ChatDataEraser
        {
            public function eraseForUser(int $userId): void {}
        });

        $recorder = new class
        {
            /** @var list<string> */
            public array $deleted = [];

            public function deleteUser(string $uid): void
            {
                $this->deleted[] = $uid;
            }
        };

        $this->app->instance('firebase.auth', $recorder);
        $this->app->instance(FirebaseAuth::class, $recorder);
        $this->recorder = $recorder;
    }

    private object $recorder;

    public function test_an_email_only_account_has_its_chat_firebase_identity_revoked(): void
    {
        $user = User::factory()->create(['firebase_uid' => null]);
        $id = (string) $user->id;

        $this->app->make(AuthService::class)->deleteAccount($user);

        $this->assertContains(
            $id,
            $this->recorder->deleted,
            'the chat Firebase UID (the numeric user id) must be revoked',
        );
    }

    public function test_a_legacy_phone_otp_identity_is_revoked_as_well(): void
    {
        $user = User::factory()->create(['firebase_uid' => 'otp-uid-xyz']);
        $id = (string) $user->id;

        $this->app->make(AuthService::class)->deleteAccount($user);

        $this->assertContains($id, $this->recorder->deleted);
        $this->assertContains('otp-uid-xyz', $this->recorder->deleted);
        $this->assertCount(2, $this->recorder->deleted, 'each identity is revoked once');
    }
}
