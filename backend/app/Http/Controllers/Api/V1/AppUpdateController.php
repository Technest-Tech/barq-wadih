<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\JsonResponse;

class AppUpdateController
{
    public function __invoke(): JsonResponse
    {
        $releases = [];
        foreach (['ios', 'android'] as $platform) {
            $policy = config("app_updates.{$platform}", []);
            $version = $policy['version'] ?? null;
            if (($policy['published'] ?? false) !== true || ! $this->validVersion($version)) {
                $releases[$platform] = null;
                continue;
            }
            if ($platform === 'android') {
                $build = filter_var($policy['build'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
                $sdk = filter_var($policy['minimum_sdk'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
                // Missing compatibility data must not recommend an unusable update.
                if ($build === false || $sdk === false) {
                    $releases[$platform] = null;
                    continue;
                }
                $releases[$platform] = [
                    'version' => $version,
                    'build' => $build,
                    'minimum_sdk' => $sdk,
                    'bundle_id' => 'com.barqwadih.barq_wadih',
                    'store_url' => 'https://play.google.com/store/apps/details?id=com.barqwadih.barq_wadih',
                ];
            } else {
                if (! $this->validVersion($policy['minimum_os'] ?? null)) {
                    $releases[$platform] = null;
                    continue;
                }
                $releases[$platform] = [
                    'version' => $version,
                    'minimum_os' => $policy['minimum_os'],
                    'bundle_id' => 'com.barqwadih.app',
                    'store_url' => 'https://apps.apple.com/app/id6800784915',
                ];
            }
        }

        return response()->json(['data' => $releases])
            ->header('Cache-Control', 'no-store');
    }

    private function validVersion(mixed $value): bool
    {
        return is_string($value) && preg_match('/^\d+(\.\d+)*$/D', $value) === 1;
    }
}
