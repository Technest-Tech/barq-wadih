<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Requests\MarketingTrackingEventRequest;
use App\Models\User;
use App\Services\SnapchatConversionsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class MarketingTrackingController extends BaseController
{
    public function __invoke(
        MarketingTrackingEventRequest $request,
        SnapchatConversionsService $snapchat,
    ): JsonResponse {
        /** @var User|null $user */
        $user = Auth::guard('sanctum')->user();

        $snapchat->send(
            event: $request->validated(),
            user: $user,
            clientIp: $request->ip(),
            clientUserAgent: $request->userAgent(),
        );

        // Measurement is deliberately best-effort. A temporary ad-platform
        // outage must not turn a completed user action into an app error.
        return $this->successResponse(
            data: null,
            message: 'Event accepted.',
            code: 202,
        );
    }
}
