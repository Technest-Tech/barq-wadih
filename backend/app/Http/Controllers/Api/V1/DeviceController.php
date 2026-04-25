<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Enums\DeviceType;
use App\Models\UserDevice;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Enum;

class DeviceController extends Controller
{
    use ApiResponses;

    // ── POST /devices ─────────────────────────────────────────────────────────

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fcm_token'   => 'required|string|max:500',
            'device_type' => ['required', new Enum(DeviceType::class)],
            'device_name' => 'nullable|string|max:100',
        ]);

        $userId = $request->user()->id;

        // If this token already belongs to another user, reassign it
        UserDevice::where('fcm_token', $data['fcm_token'])
            ->where('user_id', '!=', $userId)
            ->delete();

        // Upsert for current user
        UserDevice::updateOrCreate(
            [
                'user_id'   => $userId,
                'fcm_token' => $data['fcm_token'],
            ],
            [
                'device_type' => $data['device_type'],
                'device_name' => $data['device_name'] ?? null,
                'is_active'   => true,
            ],
        );

        return $this->successResponse(null, 'تم تسجيل الجهاز بنجاح');
    }

    // ── DELETE /devices ───────────────────────────────────────────────────────

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fcm_token' => 'required|string|max:500',
        ]);

        UserDevice::where('user_id', $request->user()->id)
            ->where('fcm_token', $data['fcm_token'])
            ->update(['is_active' => false]);

        return $this->successResponse(null, 'تم إلغاء تسجيل الجهاز');
    }
}
