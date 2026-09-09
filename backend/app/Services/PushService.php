<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\UserDevice;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\ApnsConfig;
use Kreait\Firebase\Messaging\CloudMessage;

class PushService
{
    private ?Messaging $messaging = null;

    /**
     * Resolved on first push, not in the constructor.
     *
     * The service is constructor-injected into controllers that only ever
     * read notification data; eagerly building the Firebase client made those
     * endpoints fail outright wherever no Firebase project is configured.
     */
    private function messaging(): Messaging
    {
        return $this->messaging ??= app('firebase.messaging');
    }

    // ── Send to a single user ────────────────────────────────────────────────

    /**
     * Creates an in-app notification record AND dispatches FCM push.
     */
    public function sendToUser(
        int $userId,
        string $type,
        string $titleAr,
        string $bodyAr,
        array $data = [],
    ): void {
        // 1) Create in-app notification
        Notification::create([
            'user_id' => $userId,
            'type' => $type,
            'title_ar' => $titleAr,
            'body_ar' => $bodyAr,
            'data' => $data,
            'channel' => 'both',
            'sent_at' => now(),
        ]);

        // 2) Push FCM to all active devices
        $tokens = UserDevice::where('user_id', $userId)
            ->active()
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->toArray();

        if (! empty($tokens)) {
            // iOS renders whatever badge the payload carries, verbatim. A
            // hard-coded 1 left the app icon badged for good — reading the
            // notification in-app could never bring it back down. Send the
            // recipient's real unread total instead, so it decays to 0.
            $badge = Notification::forUser($userId)->unread()->count();

            $this->dispatchFcm($tokens, $titleAr, $bodyAr, $data, $badge);
        }
    }

    // ── Send to multiple users (batch) ───────────────────────────────────────

    /**
     * Creates in-app notifications + FCM push for a list of user IDs.
     *
     * Returns how many of those users were reachable by push (i.e. had at
     * least one active device). Callers that report delivery — admin
     * campaigns — need that number; the in-app row count is just count($userIds).
     */
    public function sendToUsers(
        array $userIds,
        string $type,
        string $titleAr,
        string $bodyAr,
        array $data = [],
        ?string $titleEn = null,
        ?string $bodyEn = null,
    ): int {
        if (empty($userIds)) {
            return 0;
        }

        // 1) Bulk insert in-app notifications
        $records = collect($userIds)->map(fn (int $uid) => [
            'user_id' => $uid,
            'type' => $type,
            'title_ar' => $titleAr,
            'title_en' => $titleEn,
            'body_ar' => $bodyAr,
            'body_en' => $bodyEn,
            'data' => json_encode($data),
            'channel' => 'both',
            'sent_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ])->toArray();

        // Insert in chunks to avoid memory issues
        foreach (array_chunk($records, 500) as $chunk) {
            Notification::insert($chunk);
        }

        // 2) Collect all FCM tokens for these users
        $devices = UserDevice::whereIn('user_id', $userIds)
            ->active()
            ->whereNotNull('fcm_token')
            ->get(['user_id', 'fcm_token']);

        $tokens = $devices->pluck('fcm_token')->filter()->unique()->values()->toArray();

        if (! empty($tokens)) {
            // A single multicast cannot carry a per-recipient badge, so leave
            // it out rather than stamping every device with the same number.
            $this->dispatchFcm($tokens, $titleAr, $bodyAr, $data);
        }

        return $devices->pluck('user_id')->unique()->count();
    }

    // ── FCM dispatch ─────────────────────────────────────────────────────────

    /**
     * Sends FCM multicast in batches of 500 (Firebase limit).
     */
    private function dispatchFcm(
        array $tokens,
        string $title,
        string $body,
        array $data,
        ?int $badge = null,
    ): void {
        // Stringify data values (FCM requires all values to be strings)
        $stringData = collect($data)->map(fn ($v) => strval($v))->toArray();

        // FCM maps the common notification block onto APNs by itself, but it
        // leaves `aps.sound` unset — which lands an iPhone alert silently.
        // Ask for the default sound explicitly.
        $aps = ['sound' => 'default'];

        if ($badge !== null) {
            $aps['badge'] = $badge;
        }

        $message = CloudMessage::new()
            ->withNotification(\Kreait\Firebase\Messaging\Notification::create($title, $body))
            ->withData($stringData)
            ->withApnsConfig(
                ApnsConfig::fromArray([
                    'headers' => ['apns-priority' => '10'],
                    'payload' => ['aps' => $aps],
                ])
            );

        try {
            foreach (array_chunk($tokens, 500) as $batch) {
                $report = $this->messaging()->sendMulticast($message, $batch);

                // Retire only tokens Firebase reports as unregistered or
                // malformed. SendReport has no ->index() in kreait 7 — calling
                // it threw, which aborted this loop before any later batch was
                // sent and logged every push as fcm.dispatch_failed. Using the
                // report's own token lists also stops a transient send error
                // from deactivating a perfectly good device.
                $stale = array_merge($report->invalidTokens(), $report->unknownTokens());

                if ($stale !== []) {
                    UserDevice::whereIn('fcm_token', $stale)
                        ->update(['is_active' => false]);
                }
            }
        } catch (\Throwable $e) {
            Log::error('fcm.dispatch_failed', [
                'error' => $e->getMessage(),
                'tokens' => count($tokens),
            ]);
        }
    }
}
