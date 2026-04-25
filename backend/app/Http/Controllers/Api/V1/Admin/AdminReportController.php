<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\AdminAction;
use App\Enums\AdStatus;
use App\Enums\ReportStatus;
use App\Http\Controllers\Api\V1\BaseController;
use App\Http\Resources\AdminReportResource;
use App\Models\Report;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminReportController extends BaseController
{
    /**
     * GET /api/v1/admin/reports
     *
     * Paginated reports with filters. Pending reports first by default.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Report::with([
            'reporter:id,name,avatar',
            'ad' => fn ($q) => $q->withTrashed()->with(['images', 'user:id,name,avatar', 'category:id,name_ar']),
            'admin:id,name',
        ]);

        // ── Filters ─────────────────────────────────────────────────────
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }
        if ($request->filled('reason')) {
            $query->where('reason', $request->input('reason'));
        }
        if ($request->filled('ad_id')) {
            $query->where('ad_id', (int) $request->input('ad_id'));
        }

        // ── Sorting ─────────────────────────────────────────────────────
        $sort = $request->input('sort', 'priority');
        if ($sort === 'priority') {
            // Pending first, then by newest
            $query->orderByRaw("FIELD(status, 'pending', 'reviewed', 'resolved', 'dismissed')")
                  ->latest();
        } else {
            $query->orderBy(
                in_array($sort, ['created_at', 'status'], true) ? $sort : 'created_at',
                $request->input('dir', 'desc')
            );
        }

        $reports = $query->paginate($request->integer('per_page', 20));

        return $this->paginatedResponse(AdminReportResource::collection($reports));
    }

    /**
     * GET /api/v1/admin/reports/{report}
     */
    public function show(Report $report): JsonResponse
    {
        $report->load([
            'reporter:id,name,avatar,phone,email',
            'ad' => fn ($q) => $q->withTrashed()->with([
                'images', 'user:id,name,avatar,phone,email,is_verified', 'category:id,name_ar,name_en', 'city:id,name_ar',
            ]),
            'admin:id,name',
        ]);

        return $this->successResponse(new AdminReportResource($report));
    }

    /**
     * POST /api/v1/admin/reports/{report}/resolve
     *
     * Resolve a report with an admin action.
     */
    public function resolve(Request $request, Report $report): JsonResponse
    {
        $request->validate([
            'admin_action' => 'required|string|in:no_action,ad_removed,user_warned,user_banned',
            'admin_note'   => 'nullable|string|max:1000',
        ]);

        /** @var \App\Models\User $admin */
        $admin = $request->user();

        $report->update([
            'status'       => ReportStatus::Resolved->value,
            'admin_id'     => $admin->id,
            'admin_action' => $request->input('admin_action'),
            'admin_note'   => $request->input('admin_note'),
            'resolved_at'  => now(),
        ]);

        // ── Side effects based on admin action ──────────────────────────
        $action = AdminAction::from($request->input('admin_action'));

        if ($action === AdminAction::AdRemoved && $report->ad) {
            $report->ad->update(['status' => AdStatus::Deleted->value]);
            $report->ad->delete();
        }

        if ($action === AdminAction::UserBanned && $report->ad?->user) {
            $report->ad->user->update(['is_active' => false]);
        }

        return $this->successResponse(
            new AdminReportResource($report->fresh()),
            'تم معالجة البلاغ بنجاح.'
        );
    }

    /**
     * POST /api/v1/admin/reports/{report}/dismiss
     *
     * Dismiss a report (false/invalid report).
     */
    public function dismiss(Request $request, Report $report): JsonResponse
    {
        /** @var \App\Models\User $admin */
        $admin = $request->user();

        $report->update([
            'status'       => ReportStatus::Dismissed->value,
            'admin_id'     => $admin->id,
            'admin_action' => AdminAction::NoAction->value,
            'admin_note'   => $request->input('admin_note', 'بلاغ غير صحيح'),
            'resolved_at'  => now(),
        ]);

        return $this->successResponse(
            new AdminReportResource($report->fresh()),
            'تم رفض البلاغ.'
        );
    }
}
