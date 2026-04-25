<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class HealthController extends BaseController
{
    /**
     * System health check endpoint.
     *
     * GET /api/v1/health
     */
    public function __invoke(): JsonResponse
    {
        $services = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
            'meilisearch' => $this->checkMeilisearch(),
        ];

        $allHealthy = ! in_array('error', $services, true);

        return $this->successResponse(
            data: [
                'status' => $allHealthy ? 'ok' : 'degraded',
                'timestamp' => now()->toIso8601String(),
                'services' => $services,
            ],
            code: $allHealthy ? 200 : 503,
        );
    }

    private function checkDatabase(): string
    {
        try {
            DB::connection()->getPdo();

            return 'ok';
        } catch (\Exception) {
            return 'error';
        }
    }

    private function checkRedis(): string
    {
        try {
            Cache::store('redis')->put('health_check', true, 10);

            return 'ok';
        } catch (\Exception) {
            return 'error';
        }
    }

    private function checkMeilisearch(): string
    {
        try {
            $host = config('scout.meilisearch.host', 'http://127.0.0.1:7700');
            $key = config('scout.meilisearch.key', '');

            $ch = curl_init($host.'/health');
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT => 3,
                CURLOPT_HTTPHEADER => [
                    'Authorization: Bearer '.$key,
                ],
            ]);
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if ($httpCode === 200 && $response) {
                $data = json_decode($response, true);

                return ($data['status'] ?? '') === 'available' ? 'ok' : 'error';
            }

            return 'error';
        } catch (\Exception) {
            return 'error';
        }
    }
}
