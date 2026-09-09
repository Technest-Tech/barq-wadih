<?php

namespace App\Services;

use App\Contracts\ChatDataEraser;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FirestoreChatDataEraser implements ChatDataEraser
{
    private const FIRESTORE_SCOPE = 'https://www.googleapis.com/auth/datastore';
    private const STORAGE_SCOPE = 'https://www.googleapis.com/auth/devstorage.full_control';

    public function __construct(private readonly ImageService $images) {}

    public function eraseForUser(int $userId): void
    {
        $credentials = $this->credentials();
        $projectId = $credentials['project_id'] ?? null;

        if (! is_string($projectId) || $projectId === '') {
            throw new RuntimeException('Firebase service credentials do not contain a project_id.');
        }

        $token = $this->accessToken($credentials);

        $database = 'projects/'.rawurlencode($projectId).'/databases/(default)';
        $api = 'https://firestore.googleapis.com/v1/'.$database;
        $query = Http::withToken($token)->acceptJson()->timeout(30)->retry(2, 250)
            ->post($api.'/documents:runQuery', [
                'structuredQuery' => [
                    'from' => [['collectionId' => 'conversations']],
                    'where' => [
                        'fieldFilter' => [
                            'field' => ['fieldPath' => 'participantUids'],
                            'op' => 'ARRAY_CONTAINS',
                            'value' => ['stringValue' => (string) $userId],
                        ],
                    ],
                ],
            ])->throw()->json();

        foreach ($query as $row) {
            $conversationName = data_get($row, 'document.name');
            if (! is_string($conversationName) || $conversationName === '') {
                continue;
            }

            $conversationId = rawurldecode(basename($conversationName));
            $deletes = $this->messageDocumentNames($token, $conversationName);
            $deletes[] = $conversationName;

            foreach (array_chunk($deletes, 500) as $chunk) {
                Http::withToken($token)->acceptJson()->timeout(30)->retry(2, 250)
                    ->post($api.'/documents:batchWrite', [
                        'writes' => array_map(
                            static fn (string $name): array => ['delete' => $name],
                            $chunk,
                        ),
                    ])->throw();
            }

            $this->images->deleteDirectory("chat/{$conversationId}");
            $this->deleteFirebaseStoragePrefix($token, $projectId, "chat_images/{$conversationId}/");
            $this->deleteFirebaseStoragePrefix($token, $projectId, "chat_voice/{$conversationId}/");
        }
    }

    private function deleteFirebaseStoragePrefix(
        string $token,
        string $projectId,
        string $prefix,
    ): void {
        $bucket = config('firebase.projects.app.storage.default_bucket')
            ?: "{$projectId}.firebasestorage.app";
        $pageToken = null;

        do {
            $listing = Http::withToken($token)->acceptJson()->timeout(30)
                ->retry(2, 250, throw: false)
                ->get('https://storage.googleapis.com/storage/v1/b/'.rawurlencode($bucket).'/o', array_filter([
                    'prefix' => $prefix,
                    'pageToken' => $pageToken,
                ]));

            // The mobile app stores chat media on this server; Firebase Storage
            // is only used by the web client and the bucket may never have been
            // provisioned. "No bucket" therefore means there is genuinely no
            // media to erase, so we stop here instead of aborting the whole
            // deletion. Every other failure still throws, so the API can never
            // report success while account-linked data survives.
            if ($listing->notFound()) {
                return;
            }

            $response = $listing->throw()->json();

            foreach ($response['items'] ?? [] as $item) {
                $name = $item['name'] ?? null;
                if (is_string($name) && $name !== '') {
                    Http::withToken($token)->timeout(30)->retry(2, 250)
                        ->delete(
                            'https://storage.googleapis.com/storage/v1/b/'.rawurlencode($bucket).'/o/'.rawurlencode($name),
                        )->throw();
                }
            }

            $pageToken = $response['nextPageToken'] ?? null;
        } while (is_string($pageToken) && $pageToken !== '');
    }

    /** @return list<string> */
    private function messageDocumentNames(string $token, string $conversationName): array
    {
        $names = [];
        $pageToken = null;

        do {
            $response = Http::withToken($token)->acceptJson()->timeout(30)->retry(2, 250)
                ->get('https://firestore.googleapis.com/v1/'.$conversationName.'/messages', array_filter([
                    'pageSize' => 300,
                    'pageToken' => $pageToken,
                ]))->throw()->json();

            foreach ($response['documents'] ?? [] as $document) {
                if (isset($document['name']) && is_string($document['name'])) {
                    $names[] = $document['name'];
                }
            }

            $pageToken = $response['nextPageToken'] ?? null;
        } while (is_string($pageToken) && $pageToken !== '');

        return $names;
    }

    /**
     * Resolve the configured credential value to a readable file path, or null
     * when the value is an inline credential blob rather than a path.
     */
    private function credentialsPath(string $configured): ?string
    {
        // An inline JSON/base64 blob is never a path; skip the filesystem probe
        // so a multi-kilobyte string is not fed to is_file().
        if ($configured === '' || strlen($configured) > 4096 || str_contains($configured, "\n")) {
            return null;
        }

        if (is_file($configured)) {
            return $configured;
        }

        $fromRoot = base_path($configured);

        return is_file($fromRoot) ? $fromRoot : null;
    }

    /**
     * Mint a short-lived service access token for Firestore + Storage.
     * Overridable so tests can exercise the erasure flow without a network.
     *
     * @param  array<string, mixed>  $credentials
     */
    protected function accessToken(array $credentials): string
    {
        $auth = new ServiceAccountCredentials(
            [self::FIRESTORE_SCOPE, self::STORAGE_SCOPE],
            $credentials,
        );
        $token = $auth->fetchAuthToken()['access_token'] ?? null;

        if (! is_string($token) || $token === '') {
            throw new RuntimeException('Could not obtain a Firebase service access token.');
        }

        return $token;
    }

    /** @return array<string, mixed> */
    private function credentials(): array
    {
        $configured = config('firebase.projects.app.credentials');

        if (is_array($configured)) {
            return $configured;
        }

        if (! is_string($configured) || trim($configured) === '') {
            throw new RuntimeException('Firebase service credentials are not configured.');
        }

        $configured = trim($configured);

        // The configured value is either an inline JSON blob, a base64 blob, or
        // a path to the service-account file. Paths are usually written
        // relative to the project root ("storage/firebase-service-account.json"),
        // which resolves under `php artisan` but NOT under PHP-FPM, whose
        // working directory is the public/ front controller. Anchoring the
        // relative form to base_path() makes both contexts agree — without it
        // account deletion fails with "credentials are invalid" over HTTP while
        // passing from the CLI.
        $path = $this->credentialsPath($configured);
        if ($path !== null) {
            $contents = @file_get_contents($path);

            if ($contents === false) {
                throw new RuntimeException(
                    'Firebase service credentials file could not be read: '.$path,
                );
            }

            $configured = $contents;
        }

        $decoded = json_decode($configured, true);
        if (! is_array($decoded)) {
            $base64 = base64_decode($configured, true);
            $decoded = is_string($base64) ? json_decode($base64, true) : null;
        }

        if (! is_array($decoded)) {
            throw new RuntimeException('Firebase service credentials are invalid.');
        }

        return $decoded;
    }
}
