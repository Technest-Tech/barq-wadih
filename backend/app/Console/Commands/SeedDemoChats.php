<?php

namespace App\Console\Commands;

use App\Models\Ad;
use App\Models\User;
use App\Services\ChatService;
use Google\Auth\CredentialsLoader;
use Google\Auth\OAuth2;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

/**
 * Seeds pre-populated chat history into the App Review demo account.
 *
 * Apple rejected 1.0.1 (8) under Guideline 2.1 because the reviewer signed in
 * to the demo account, found an empty Messages tab, and therefore could not
 * reach the Report / Block controls (both live inside a conversation).
 *
 * This command creates real conversations — same document shape the app writes
 * — between the demo account and the sellers of live ads, so the reviewer sees
 * populated threads on first launch.
 *
 * Firestore is written through the REST API because google/cloud-firestore is
 * not installed; only kreait/laravel-firebase (Auth + Messaging) is. The
 * service-account credentials it already uses are reused here.
 *
 * Usage (on the server, where Firebase credentials and MySQL both exist):
 *
 *   php artisan demo:seed-chats
 *   php artisan demo:seed-chats --email=omarrr3@gmail.com --count=3
 *   php artisan demo:seed-chats --dry-run
 *
 * Re-runnable: conversation and message documents use deterministic ids, so a
 * second run replaces the same thread rather than duplicating it.
 */
class SeedDemoChats extends Command
{
    protected $signature = 'demo:seed-chats
        {--email=omarrr3@gmail.com : Email of the App Review demo account}
        {--count=3 : How many conversations to create}
        {--seller-domain=barqwadih.sa : Only seed against sellers on this email domain}
        {--allow-real-sellers : Drop the demo-domain guard and use live sellers}
        {--dry-run : Print what would be written without touching Firestore}
        {--verify : Read the seeded threads back from Firestore and report}';

    protected $description = 'Seed pre-populated chat history into the App Review demo account';

    private const SCOPE = 'https://www.googleapis.com/auth/datastore';

    /** Scripted exchanges. Each entry alternates buyer → seller → buyer → seller. */
    private const SCRIPTS = [
        [
            ['buyer',  'السلام عليكم، هل السلعة ما زالت متوفرة؟'],
            ['seller', 'وعليكم السلام، نعم متوفرة وبحالة ممتازة.'],
            ['buyer',  'ممكن آخر سعر؟ وهل يمكن المعاينة اليوم؟'],
            ['seller', 'السعر قابل للتفاوض البسيط، والمعاينة متاحة بعد العصر.'],
        ],
        [
            ['buyer',  'مساء الخير، أبغى أستفسر عن حالة الغرض.'],
            ['seller', 'مساء النور، الغرض نظيف والاستخدام خفيف.'],
            ['buyer',  'تمام، ممكن ترسل لي صور إضافية؟'],
            ['seller', 'أكيد، أرسلها لك خلال ساعة إن شاء الله.'],
        ],
        [
            ['buyer',  'هل تقبل التوصيل داخل نفس المدينة؟'],
            ['seller', 'نعم، التوصيل متاح داخل المدينة برسوم رمزية.'],
            ['buyer',  'ممتاز، سأتواصل معك لتحديد الموعد.'],
            ['seller', 'في انتظارك، وشكراً لتواصلك.'],
        ],
        [
            ['buyer',  'السلام عليكم، الإعلان ما زال قائماً؟'],
            ['seller', 'وعليكم السلام، نعم ما زال قائماً.'],
            ['buyer',  'طيب، أحتاج أتأكد من المقاسات قبل الحجز.'],
            ['seller', 'المقاسات مذكورة في وصف الإعلان بالتفصيل.'],
        ],
    ];

    public function handle(ChatService $chat): int
    {
        $email  = (string) $this->option('email');
        $count  = max(1, (int) $this->option('count'));
        $dryRun = (bool) $this->option('dry-run');
        $verify = (bool) $this->option('verify');

        // Verifying is a read against the live project, so it needs a token.
        if ($verify) {
            $dryRun = false;
        }

        $demo = User::where('email', $email)->first();

        if (! $demo) {
            $this->error("Demo user not found: {$email}");

            return self::FAILURE;
        }

        $this->info("Demo account: #{$demo->id} — {$demo->name} <{$demo->email}>");

        // Live ads that belong to somebody else, newest first, one per seller so
        // the reviewer gets distinct people to report and block.
        $domain    = trim((string) $this->option('seller-domain'));
        $allowReal = (bool) $this->option('allow-real-sellers');

        $query = Ad::query()
            ->active()
            ->where('user_id', '!=', $demo->id)
            ->with(['user', 'images']);

        // Every 'seller' line in SCRIPTS is written with that seller's own id as
        // senderUid, so the thread lands in their inbox containing words they
        // never wrote. Against a live account that is fabricated history, so
        // stay on the seeded demo accounts unless told otherwise.
        if (! $allowReal && $domain !== '') {
            $query->whereHas('user', fn ($q) => $q->where('email', 'like', '%@'.$domain));
        }

        $ads = $query->latest('id')->get()->unique('user_id')->take($count);

        if ($ads->isEmpty()) {
            $this->error($allowReal || $domain === ''
                ? 'No active ads from other users were found — nothing to seed.'
                : "No active ads from sellers on @{$domain} were found. Seed the demo "
                    .'accounts first, or pass --allow-real-sellers to use live sellers.');

            return self::FAILURE;
        }

        if ($allowReal) {
            $this->warn('--allow-real-sellers is set: these threads will appear in real');
            $this->warn('sellers\' inboxes, quoting messages they never sent.');
        } else {
            $this->line("Sellers restricted to @{$domain} demo accounts.");
        }

        if ($ads->count() < $count) {
            $this->warn("Only {$ads->count()} distinct seller(s) available — asked for {$count}.");
        }

        $projectId = $this->projectId();
        $token     = $dryRun ? null : $this->accessToken();

        if ($verify) {
            return $this->verifySeeded($projectId, $token, $chat, $demo, $ads);
        }

        $created = 0;

        foreach ($ads->values() as $i => $ad) {
            $seller = $ad->user;
            $meta   = $chat->buildConversationMetadata($demo, $ad);
            $script = self::SCRIPTS[$i % count(self::SCRIPTS)];

            $convId = $meta['conversation_id'];
            $this->line("  → {$convId}  ({$seller->name} — {$ad->title})");

            if ($dryRun) {
                foreach ($script as [$who, $text]) {
                    $this->line(sprintf('       %-6s %s', $who, $text));
                }
                $created++;

                continue;
            }

            $this->writeConversation($projectId, $token, $meta, $ad, $demo, $seller, $script);
            $created++;
        }

        $this->newLine();
        $this->info($dryRun
            ? "Dry run complete — {$created} conversation(s) would be created."
            : "Done — {$created} conversation(s) seeded for {$email}.");

        if (! $dryRun) {
            $this->newLine();
            $this->comment('Now sign in to the app as the demo account and confirm the');
            $this->comment('Messages tab lists the threads before replying to App Review.');
        }

        return self::SUCCESS;
    }

    // ── Verification ─────────────────────────────────────────────────────────

    /**
     * Reads each seeded thread back and reports what Firestore actually holds,
     * so a run can be confirmed without trusting the write responses alone.
     *
     * @param  \Illuminate\Support\Collection<int, Ad>  $ads
     */
    private function verifySeeded(
        string $projectId,
        string $token,
        ChatService $chat,
        User $demo,
        $ads,
    ): int {
        $base = "https://firestore.googleapis.com/v1/projects/{$projectId}/databases/(default)/documents";
        $ok   = true;

        foreach ($ads->values() as $ad) {
            $meta   = $chat->buildConversationMetadata($demo, $ad);
            $convId = $meta['conversation_id'];

            $doc = $this->firestoreGet($token, "{$base}/conversations/{$convId}");

            if (! $doc) {
                $this->error("  MISSING  {$convId} — conversation document not found");
                $ok = false;

                continue;
            }

            $msgs   = $this->firestoreGet($token, "{$base}/conversations/{$convId}/messages");
            $count  = count($msgs['documents'] ?? []);
            $ids    = array_map(
                static fn (array $d): string => basename((string) ($d['name'] ?? '')),
                $msgs['documents'] ?? [],
            );
            $last   = $doc['fields']['lastMessage']['stringValue'] ?? '';
            $unread = $doc['fields']['unreadCount']['mapValue']['fields'][strval($demo->id)]['integerValue'] ?? '?';

            $this->info("  OK  {$convId} — {$count} message(s), demo unread={$unread}");
            $this->line('      ids:  '.implode(', ', $ids));
            $this->line('      last: '.$last);
        }

        return $ok ? self::SUCCESS : self::FAILURE;
    }

    // ── Firestore REST ───────────────────────────────────────────────────────

    /**
     * Writes the conversation document and its messages subcollection.
     *
     * @param  array<int, array{0: string, 1: string}>  $script
     */
    private function writeConversation(
        string $projectId,
        string $token,
        array $meta,
        Ad $ad,
        User $demo,
        User $seller,
        array $script,
    ): void {
        $base = "https://firestore.googleapis.com/v1/projects/{$projectId}/databases/(default)/documents";

        $convId   = $meta['conversation_id'];
        $demoId   = strval($demo->id);
        $sellerId = strval($seller->id);

        // Space the messages a few minutes apart, ending ~10 minutes ago, so the
        // thread reads like a real recent exchange rather than a bulk import.
        $step  = 4 * 60;
        $start = time() - (count($script) * $step) - 600;

        $lastText     = '';
        $lastSenderId = '';
        $lastAt       = $start;
        $demoUnread   = 0;

        foreach ($script as $n => [$who, $text]) {
            $senderId = $who === 'buyer' ? $demoId : $sellerId;
            $sentAt   = $start + ($n * $step);

            // Unread only counts messages the demo account has not opened, i.e.
            // the seller's. Leaving these unread puts a badge on the tab, which
            // makes the populated thread obvious the moment the app opens.
            $isRead = $who === 'buyer';
            if (! $isRead) {
                $demoUnread++;
            }

            // Deterministic id so PATCH upserts: re-running overwrites the same
            // four messages instead of appending a second copy of the thread.
            $msgId = sprintf('seed-%02d', $n + 1);

            $this->firestore($token, 'PATCH', "{$base}/conversations/{$convId}/messages/{$msgId}", [
                'fields' => [
                    'senderUid' => ['stringValue' => $senderId],
                    'senderId'  => ['stringValue' => $senderId],
                    'text'      => ['stringValue' => $text],
                    'type'      => ['stringValue' => 'text'],
                    'imageUrl'  => ['nullValue' => null],
                    'isRead'    => ['booleanValue' => $isRead],
                    'readAt'    => $isRead
                        ? ['timestampValue' => $this->ts($sentAt + 30)]
                        : ['nullValue' => null],
                    'createdAt' => ['timestampValue' => $this->ts($sentAt)],
                ],
            ]);

            $lastText     = $text;
            $lastSenderId = $senderId;
            $lastAt       = $sentAt;
        }

        $adImage = $ad->images()->orderBy('sort_order')->value('image_url');

        // PATCH without an updateMask creates the document if it is missing and
        // fully replaces it otherwise — safe to re-run.
        $this->firestore($token, 'PATCH', "{$base}/conversations/{$convId}", [
            'fields' => [
                'participantIds'      => $this->stringArray($meta['participant_ids']),
                'participantUids'     => $this->stringArray($meta['participant_uids']),
                'adId'                => ['stringValue' => strval($ad->id)],
                'adTitle'             => ['stringValue' => (string) $ad->title],
                'adImage'             => $adImage
                    ? ['stringValue' => $adImage]
                    : ['nullValue' => null],
                'lastMessage'         => ['stringValue' => $lastText],
                'lastMessageAt'       => ['timestampValue' => $this->ts($lastAt)],
                'lastMessageSenderId' => ['stringValue' => $lastSenderId],
                'unreadCount'         => ['mapValue' => ['fields' => [
                    $demoId   => ['integerValue' => strval($demoUnread)],
                    $sellerId => ['integerValue' => '0'],
                ]]],
                'peerNames'           => ['mapValue' => ['fields' => [
                    $demoId   => ['stringValue' => (string) $demo->name],
                    $sellerId => ['stringValue' => (string) $seller->name],
                ]]],
                'peerAvatars'         => ['mapValue' => ['fields' => [
                    $demoId   => $demo->avatar_url
                        ? ['stringValue' => $demo->avatar_url]
                        : ['nullValue' => null],
                    $sellerId => $seller->avatar_url
                        ? ['stringValue' => $seller->avatar_url]
                        : ['nullValue' => null],
                ]]],
                'createdAt'           => ['timestampValue' => $this->ts($start)],
                'updatedAt'           => ['timestampValue' => $this->ts($lastAt)],
            ],
        ]);
    }

    /** @param  array<int, string>  $values */
    private function stringArray(array $values): array
    {
        return ['arrayValue' => ['values' => array_map(
            static fn (string $v): array => ['stringValue' => $v],
            $values,
        )]];
    }

    private function ts(int $epoch): string
    {
        return gmdate('Y-m-d\TH:i:s\Z', $epoch);
    }

    /** @return array<string, mixed>|null */
    private function firestoreGet(string $token, string $url): ?array
    {
        $res = Http::withToken($token)->acceptJson()->get($url);

        return $res->successful() ? $res->json() : null;
    }

    private function firestore(string $token, string $method, string $url, array $body): void
    {
        $res = Http::withToken($token)
            ->acceptJson()
            ->send($method, $url, ['json' => $body]);

        if ($res->failed()) {
            $this->error("  Firestore {$method} failed ({$res->status()}): ".$res->body());
            throw new \RuntimeException('Firestore write failed — aborting.');
        }
    }

    // ── Credentials ──────────────────────────────────────────────────────────

    /** Mints a short-lived OAuth token from the same service account kreait uses. */
    private function accessToken(): string
    {
        $json = $this->serviceAccount();

        $oauth = new OAuth2([
            'audience'             => 'https://oauth2.googleapis.com/token',
            'issuer'               => $json['client_email'],
            'scope'                => self::SCOPE,
            'signingAlgorithm'     => 'RS256',
            'signingKey'           => $json['private_key'],
            'tokenCredentialUri'   => 'https://oauth2.googleapis.com/token',
        ]);

        $token = $oauth->fetchAuthToken()['access_token'] ?? null;

        if (! $token) {
            throw new \RuntimeException('Could not mint a Google access token.');
        }

        return $token;
    }

    /** @return array<string, mixed> */
    private function serviceAccount(): array
    {
        $candidates = array_filter([
            config('firebase.projects.app.credentials'),
            env('FIREBASE_CREDENTIALS'),
            env('GOOGLE_APPLICATION_CREDENTIALS'),
        ]);

        foreach ($candidates as $candidate) {
            if (is_array($candidate)) {
                return $candidate;
            }
            if (is_string($candidate) && is_file($candidate)) {
                return json_decode((string) file_get_contents($candidate), true);
            }
        }

        // Last resort: whatever the Google auth library can auto-discover.
        $discovered = CredentialsLoader::fromEnv() ?? CredentialsLoader::fromWellKnownFile();

        if (is_array($discovered)) {
            return $discovered;
        }

        throw new \RuntimeException(
            'No Firebase service-account credentials found. Set FIREBASE_CREDENTIALS '.
            'or GOOGLE_APPLICATION_CREDENTIALS to the service-account JSON path.'
        );
    }

    private function projectId(): string
    {
        $json = $this->serviceAccount();

        return $json['project_id']
            ?? env('FIREBASE_PROJECT_ID')
            ?? throw new \RuntimeException('Could not determine the Firebase project id.');
    }
}
