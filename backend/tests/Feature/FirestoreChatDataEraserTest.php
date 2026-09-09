<?php

namespace Tests\Feature;

use App\Services\FirestoreChatDataEraser;
use App\Services\ImageService;
use Illuminate\Http\Client\Request;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Account deletion erases chat data before it touches SQL, so a failure here
 * must never be swallowed — and must never abort deletion for a condition that
 * simply means "there is nothing to erase".
 */
class FirestoreChatDataEraserTest extends TestCase
{
    private const CONV = 'projects/p/databases/(default)/documents/conversations/conv_1';

    protected function setUp(): void
    {
        parent::setUp();

        config()->set('firebase.projects.app.credentials', [
            'project_id' => 'barqwadih-test',
            'client_email' => 'svc@example.test',
        ]);
        config()->set('firebase.projects.app.storage.default_bucket', null);
    }

    private function eraser(): FirestoreChatDataEraser
    {
        return new class($this->app->make(ImageService::class)) extends FirestoreChatDataEraser
        {
            protected function accessToken(array $credentials): string
            {
                return 'test-token';
            }
        };
    }

    /** @return array<string, mixed> */
    private function firestoreStubs(): array
    {
        return [
            'firestore.googleapis.com/*/documents:runQuery' => Http::response([
                ['document' => ['name' => self::CONV]],
            ]),
            'firestore.googleapis.com/*/messages*' => Http::response(['documents' => []]),
            'firestore.googleapis.com/*/documents:batchWrite' => Http::response(['writeResults' => []]),
        ];
    }

    public function test_a_project_without_a_storage_bucket_still_completes_erasure(): void
    {
        Http::fake($this->firestoreStubs() + [
            'storage.googleapis.com/*' => Http::response([
                'error' => ['code' => 404, 'message' => 'The specified bucket does not exist.'],
            ], 404),
        ]);

        $this->eraser()->eraseForUser(1);

        // The conversation and its messages are still deleted from Firestore.
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'documents:batchWrite'));
        $this->assertTrue(true);
    }

    public function test_a_storage_failure_that_is_not_a_missing_bucket_aborts_the_deletion(): void
    {
        Http::fake($this->firestoreStubs() + [
            'storage.googleapis.com/*' => Http::response(['error' => 'boom'], 500),
        ]);

        $this->expectException(RequestException::class);

        $this->eraser()->eraseForUser(1);
    }

    public function test_a_firestore_failure_aborts_the_deletion(): void
    {
        Http::fake([
            'firestore.googleapis.com/*' => Http::response(['error' => 'boom'], 500),
            'storage.googleapis.com/*' => Http::response([], 200),
        ]);

        $this->expectException(RequestException::class);

        $this->eraser()->eraseForUser(1);
    }

    public function test_stored_chat_objects_are_deleted_when_the_bucket_exists(): void
    {
        Http::fake($this->firestoreStubs() + [
            'storage.googleapis.com/storage/v1/b/*/o?*' => Http::sequence()
                ->push(['items' => [['name' => 'chat_images/conv_1/a.jpg']]])
                ->whenEmpty(Http::response(['items' => []])),
            'storage.googleapis.com/storage/v1/b/*/o/*' => Http::response([], 204),
            'storage.googleapis.com/*' => Http::response(['items' => []]),
        ]);

        $this->eraser()->eraseForUser(1);

        Http::assertSent(fn (Request $r) => $r->method() === 'DELETE'
            && str_contains(rawurldecode($r->url()), 'chat_images/conv_1/a.jpg'));
    }

    public function test_a_credentials_path_relative_to_the_project_root_resolves_off_the_cwd(): void
    {
        $relative = 'storage/app/qa-service-account.json';
        $absolute = base_path($relative);
        @mkdir(dirname($absolute), 0777, true);
        file_put_contents($absolute, json_encode([
            'project_id' => 'barqwadih-test',
            'client_email' => 'svc@example.test',
        ]));

        config()->set('firebase.projects.app.credentials', $relative);

        // PHP-FPM serves requests with the working directory set to public/,
        // where a project-relative path does not resolve. The eraser must still
        // find the file, or account deletion 500s in production but passes in CI.
        $previous = getcwd();
        chdir(base_path('public'));

        try {
            Http::fake($this->firestoreStubs() + [
                'storage.googleapis.com/*' => Http::response([], 404),
            ]);

            $this->eraser()->eraseForUser(1);

            Http::assertSent(fn (Request $r) => str_contains($r->url(), 'documents:runQuery'));
        } finally {
            chdir($previous);
            @unlink($absolute);
        }
    }

    public function test_an_unreadable_credentials_file_aborts_the_deletion(): void
    {
        config()->set('firebase.projects.app.credentials', 'storage/app/does-not-exist.json');

        $this->expectException(\RuntimeException::class);

        $this->eraser()->eraseForUser(1);
    }
}
