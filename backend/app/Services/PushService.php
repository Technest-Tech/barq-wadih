<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\UserDevice;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;

class PushService
{
    private Messaging $messaging;

    public function __construct()
    {
        $this->messaging = app('firebase.messaging');
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
            'user_id'  => $userId,
            'type'     => $type,
            'title_ar' => $titleAr,
            'body_ar'  => $bodyAr,
            'data'     => $data,
            'channel'  => 'both',
            'sent_at'  => now(),
        ]);

        // 2) Push FCM to all active devices
        $tokens = UserDevice::where('user_id', $userId)
            ->active()
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->toArray();

        if (!empty($tokens)) {
            $this->dispatchFcm($tokens, $titleAr, $bodyAr, $data);
        }
    }

    // ── Send to multiple users (batch) ───────────────────────────────────────

    /**
     * Creates in-app notifications + FCM push for a list of user IDs.
     */
    public function sendToUsers(
        array $userIds,
        string $type,
        string $titleAr,
        string $bodyAr,
        array $data = [],
    ): void {
        if (empty($userIds)) {
            return;
        }

        // 1) Bulk insert in-app notifications
        $records = collect($userIds)->map(fn (int $uid) => [
            'user_id'    => $uid,
            'type'       => $type,
            'title_ar'   => $titleAr,
            'body_ar'    => $bodyAr,
            'data'       => json_encode($data),
            'channel'    => 'both',
            'sent_at'    => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ])->toArray();

        // Insert in chunks to avoid memory issues
        foreach (array_chunk($records, 500) as $chunk) {
            Notification::insert($chunk);
        }

        // 2) Collect all FCM tokens for these users
        $tokens = UserDevice::whereIn('user_id', $userIds)
            ->active()
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->toArray();

        if (!empty($tokens)) {
            $this->dispatchFcm($tokens, $titleAr, $bodyAr, $data);
        }
    }

    // ── FCM dispatch ─────────────────────────────────────────────────────────

    /**
     * Sends FCM multicast in batches of 500 (Firebase limit).
     */
    private function dispatchFcm(array $tokens, string $title, string $body, array $data): void
    {
        // Stringify data values (FCM requires all values to be strings)
        $stringData = collect($data)->map(fn ($v) => strval($v))->toArray();

        $message = CloudMessage::new()
            ->withNotification(\Kreait\Firebase\Messaging\Notification::create($title, $body))
            ->withData($stringData);

        try {
            foreach (array_chunk($tokens, 500) as $batch) {
                $report = $this->messaging->sendMulticast($message, $batch);

                // Deactivate invalid tokens
                if ($report->hasFailures()) {
                    foreach ($report->failures()->getItems() as $failure) {
                        $failedToken = $batch[$failure->index()] ?? null;
                        if ($failedToken) {
                            UserDevice::where('fcm_token', $failedToken)
                                ->update(['is_active' => false]);
                        }
                    }
                }
            }
        } catch (\Throwable $e) {
            Log::error('fcm.dispatch_failed', [
                'error'  => $e->getMessage(),
                'tokens' => count($tokens),
            ]);
        }
    }
}
