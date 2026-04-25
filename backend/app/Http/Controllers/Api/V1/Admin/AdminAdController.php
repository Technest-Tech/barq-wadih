<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\AdStatus;
use App\Enums\ModerationStatus;
use App\Http\Controllers\Api\V1\BaseController;
use App\Http\Resources\AdminAdResource;
use App\Models\Ad;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminAdController extends BaseController
{
    /**
     * GET /api/v1/admin/ads
     *
     * Paginated ad list with advanced filters for admin moderation.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Ad::withTrashed()
            ->with(['user:id,name,avatar,phone', 'category:id,name_ar,name_en', 'city:id,name_ar,name_en', 'region:id,name_ar,name_en', 'images'])
            ->withCount('reports');

        // ── Keyword search ──────────────────────────────────────────────
        if ($request->filled('q')) {
            $search = (string) $request->input('q');
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%")
                  ->orWhere('id', $search);
            });
        }

        // ── Status filters ──────────────────────────────────────────────
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }
        if ($request->filled('moderation_status')) {
            $query->where('moderation_status', $request->input('moderation_status'));
        }

        // ── Relation filters ────────────────────────────────────────────
        if ($request->filled('category_id')) {
            $query->where('category_id', (int) $request->input('category_id'));
        }
        if ($request->filled('city_id')) {
            $query->where('city_id', (int) $request->input('city_id'));
        }
        if ($request->filled('region_id')) {
            $query->where('region_id', (int) $request->input('region_id'));
        }
        if ($request->filled('user_id')) {
            $query->where('user_id', (int) $request->input('user_id'));
        }

        // ── Date range ──────────────────────────────────────────────────
        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->input('date_from'));
        }
        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->input('date_to'));
        }

        // ── Has reports ─────────────────────────────────────────────────
        if ($request->boolean('has_reports')) {
            $query->has('reports');
        }

        // ── Sorting ─────────────────────────────────────────────────────
        $sortField = $request->input('sort', 'created_at');
        $sortDir   = $request->input('dir', 'desc');
        $allowed   = ['created_at', 'price', 'views_count', 'reports_count', 'title'];

        if (in_array($sortField, $allowed, true)) {
            if ($sortField === 'reports_count') {
                $query->orderBy('reports_count', $sortDir);
            } else {
                $query->orderBy($sortField, $sortDir);
            }
        } else {
            $query->latest();
        }

        $ads = $query->paginate($request->integer('per_page', 20));

        return $this->paginatedResponse(AdminAdResource::collection($ads));
    }

    /**
     * GET /api/v1/admin/ads/{ad}
     *
     * Full ad detail for moderation review.
     */
    public function show(int $id): JsonResponse
    {
        $ad = Ad::withTrashed()
            ->with([
                'user:id,name,avatar,phone,email,is_verified,is_dealer,role',
                'category:id,name_ar,name_en',
                'city:id,name_ar,name_en',
                'region:id,name_ar,name_en',
                'images',
                'fieldValues.field',
                'reports' => fn ($q) => $q->with(['reporter:id,name', 'admin:id,name'])->latest(),
            ])
            ->withCount('reports')
            ->findOrFail($id);

        return $this->successResponse(new AdminAdResource($ad));
    }

    /**
     * POST /api/v1/admin/ads/{ad}/approve
     *
     * Approve an ad for publishing.
     */
    public function approve(int $id): JsonResponse
    {
        $ad = Ad::withTrashed()->findOrFail($id);

        $ad->update([
            'moderation_status' => ModerationStatus::Approved->value,
            'moderation_note'   => null,
            'status'            => AdStatus::Active->value,
            'published_at'      => $ad->published_at ?? now(),
        ]);

        return $this->successResponse(
            new AdminAdResource($ad->fresh()),
            'تم قبول الإعلان بنجاح.'
        );
    }

    /**
     * POST /api/v1/admin/ads/{ad}/reject
     *
     * Reject an ad with a reason.
     */
    public function reject(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'rejection_reason' => 'required|string|max:500',
        ]);

        $ad = Ad::withTrashed()->findOrFail($id);

        $ad->update([
            'moderation_status' => ModerationStatus::Rejected->value,
            'moderation_note'   => $request->input('rejection_reason'),
            'status'            => AdStatus::Rejected->value,
        ]);

        return $this->successResponse(
            new AdminAdResource($ad->fresh()),
            'تم رفض الإعلان.'
        );
    }

    /**
     * DELETE /api/v1/admin/ads/{ad}
     *
     * Soft delete an ad with optional admin note.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $ad = Ad::withTrashed()->findOrFail($id);

        if ($request->filled('admin_note')) {
            $ad->update(['moderation_note' => $request->input('admin_note')]);
        }

        $ad->update(['status' => AdStatus::Deleted->value]);
        $ad->delete();

        return $this->successResponse(null, 'تم حذف الإعلان بنجاح.');
    }

    /**
     * POST /api/v1/admin/ads/{ad}/restore
     *
     * Restore a soft-deleted ad.
     */
    public function restore(int $id): JsonResponse
    {
        $ad = Ad::onlyTrashed()->findOrFail($id);
        $ad->restore();

        $ad->update([
            'status' => AdStatus::Active->value,
            'moderation_status' => ModerationStatus::Approved->value,
        ]);

        return $this->successResponse(
            new AdminAdResource($ad->fresh()),
            'تم استعادة الإعلان بنجاح.'
        );
    }
}
