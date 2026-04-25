<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\BaseController;
use App\Models\SystemSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminSettingsController extends BaseController
{
    /**
     * GET /admin/settings
     * List all settings grouped by category.
     */
    public function index(): JsonResponse
    {
        $settings = SystemSetting::orderBy('group')->orderBy('key')->get();

        $grouped = $settings->groupBy('group')->map(function ($items, $group) {
            return [
                'group'    => $group,
                'settings' => $items->map(fn (SystemSetting $s) => [
                    'key'         => $s->key,
                    'value'       => $s->value,
                    'type'        => $s->type->value,
                    'type_label'  => $s->type->label(),
                    'group'       => $s->group,
                    'description' => $s->description,
                    'updated_at'  => $s->updated_at?->toISOString(),
                ]),
            ];
        })->values();

        return $this->successResponse($grouped);
    }

    /**
     * GET /admin/settings/{key}
     */
    public function show(string $key): JsonResponse
    {
        $setting = SystemSetting::where('key', $key)->first();

        if (! $setting) {
            return $this->errorResponse('الإعداد غير موجود', 404);
        }

        return $this->successResponse([
            'key'         => $setting->key,
            'value'       => $setting->value,
            'type'        => $setting->type->value,
            'type_label'  => $setting->type->label(),
            'group'       => $setting->group,
            'description' => $setting->description,
            'updated_at'  => $setting->updated_at?->toISOString(),
        ]);
    }

    /**
     * PUT /admin/settings/{key}
     */
    public function update(Request $request, string $key): JsonResponse
    {
        $setting = SystemSetting::where('key', $key)->first();

        if (! $setting) {
            return $this->errorResponse('الإعداد غير موجود', 404);
        }

        $request->validate([
            'value' => ['required'],
        ]);

        SystemSetting::set($key, $request->input('value'));

        return $this->successResponse([
            'key'   => $key,
            'value' => SystemSetting::get($key),
        ], 'تم تحديث الإعداد');
    }

    /**
     * PUT /admin/settings/bulk
     * Bulk update multiple settings.
     */
    public function bulkUpdate(Request $request): JsonResponse
    {
        $request->validate([
            'settings'         => ['required', 'array', 'min:1'],
            'settings.*.key'   => ['required', 'string'],
            'settings.*.value' => ['required'],
        ]);

        $updated = [];
        foreach ($request->input('settings') as $item) {
            $exists = SystemSetting::where('key', $item['key'])->exists();
            if ($exists) {
                SystemSetting::set($item['key'], $item['value']);
                $updated[] = $item['key'];
            }
        }

        return $this->successResponse([
            'updated' => $updated,
            'count'   => count($updated),
        ], 'تم تحديث ' . count($updated) . ' إعدادات');
    }
}
