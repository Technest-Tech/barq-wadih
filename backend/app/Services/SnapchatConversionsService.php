<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

class SnapchatConversionsService
{
    public function send(
        array $event,
        ?User $user,
        ?string $clientIp,
        ?string $clientUserAgent,
    ): bool {
        $appId = config('services.snapchat.app_id');
        $token = config('services.snapchat.capi_token');
        $endpoint = rtrim((string) config('services.snapchat.endpoint'), '/');

        if (! is_string($appId) || $appId === '' || ! is_string($token) || $token === '') {
            $this->audit('warning', 'Snapchat conversion skipped: CAPI credentials are not configured.', [
                'event_name' => $event['event_name'] ?? null,
                'event_id' => $event['event_id'] ?? null,
            ]);

            return false;
        }

        $trackingEnabled = (bool) data_get(
            $event,
            'app_data.advertiser_tracking_enabled',
            false,
        );
        $userData = array_filter([
            'client_ip_address' => $clientIp,
            'client_user_agent' => $clientUserAgent,
            // PII-based advanced matching is used only when the device reports
            // that advertising tracking is enabled (ATT on iOS).
            'external_id' => $trackingEnabled && $user
                ? $this->hash((string) $user->id)
                : null,
            'em' => $trackingEnabled && $user?->email
                ? $this->hash(mb_strtolower(trim($user->email)))
                : null,
            'ph' => $trackingEnabled && $user?->phone
                ? $this->hash($this->normalizePhone($user->phone))
                : null,
        ], static fn (mixed $value): bool => $value !== null && $value !== '');

        $appData = $event['app_data'];
        // Laravel's ConvertEmptyStringsToNull middleware runs before request
        // validation. Snap requires missing extinfo values to remain empty
        // strings in their exact array positions; null makes the whole event
        // fail with "Request parsing failed".
        $appData['extinfo'] = array_map(
            static fn (mixed $value): mixed => $value ?? '',
            $appData['extinfo'],
        );

        $payload = [
            'data' => [[
                'event_name' => $event['event_name'],
                'event_time' => $event['event_time'],
                'event_id' => $event['event_id'],
                'action_source' => 'MOBILE_APP',
                'event_source_url' => config('services.snapchat.event_source_url'),
                'user_data' => $userData,
                'app_data' => $appData,
                'custom_data' => $event['custom_data'] ?? [],
            ]],
        ];

        try {
            $response = Http::acceptJson()
                ->asJson()
                ->timeout(6)
                ->connectTimeout(3)
                ->withQueryParameters(['access_token' => $token])
                ->post("{$endpoint}/{$appId}/events", $payload);

            $responseBody = $response->json();
            $snapStatus = is_array($responseBody)
                ? strtoupper((string) ($responseBody['status'] ?? ''))
                : '';
            $auditContext = [
                'event_name' => $event['event_name'],
                'event_id' => $event['event_id'],
                'platform' => data_get($event, 'app_data.extinfo.0'),
                'app_id' => data_get($event, 'app_data.app_id'),
                'http_status' => $response->status(),
                'snap_status' => $snapStatus !== '' ? $snapStatus : null,
                'reason' => is_array($responseBody) ? ($responseBody['reason'] ?? null) : null,
                'error_codes' => is_array($responseBody)
                    ? data_get($responseBody, 'errors.codes')
                    : null,
                'error_messages' => is_array($responseBody)
                    ? data_get($responseBody, 'errors.error_msgs')
                    : null,
            ];

            if ($response->successful() && $snapStatus === 'VALID') {
                $this->audit('info', 'Snapchat conversion accepted.', $auditContext);

                return true;
            }

            $this->audit('warning', 'Snapchat conversion rejected.', $auditContext);
        } catch (Throwable $exception) {
            $this->audit('warning', 'Snapchat conversion request failed.', [
                'event_name' => $event['event_name'],
                'event_id' => $event['event_id'],
                'error_type' => $exception::class,
                // Avoid leaking request URLs because they contain the CAPI
                // access token as a query parameter.
                'error' => preg_replace('/access_token=[^&\s]+/', 'access_token=[redacted]', $exception->getMessage()),
            ]);
        }

        return false;
    }

    private function audit(string $level, string $message, array $context): void
    {
        Log::channel('marketing_tracking')->log($level, $message, array_filter(
            $context,
            static fn (mixed $value): bool => $value !== null && $value !== '' && $value !== [],
        ));
    }

    private function hash(string $value): string
    {
        return hash('sha256', $value);
    }

    private function normalizePhone(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';

        if (str_starts_with($digits, '05')) {
            return '966'.substr($digits, 1);
        }
        if (str_starts_with($digits, '00966')) {
            return substr($digits, 2);
        }

        return $digits;
    }
}
