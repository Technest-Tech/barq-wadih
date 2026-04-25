<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Enums\ReportReason;
use App\Models\Ad;
use App\Models\Report;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Enum;

class ReportController extends Controller
{
    use ApiResponses;

    // ── GET /reports/reasons ──────────────────────────────────────────────────

    public function reasons(): JsonResponse
    {
        $reasons = collect(ReportReason::cases())->map(fn (ReportReason $r) => [
            'value' => $r->value,
            'label' => $r->label(),
        ]);

        return $this->successResponse($reasons);
    }

    // ── POST /ads/{ad}/report ─────────────────────────────────────────────────

    public function store(Request $request, Ad $ad): JsonResponse
    {
        $data = $request->validate([
            'reason'      => ['required', new Enum(ReportReason::class)],
            'description' => 'nullable|string|max:1000',
        ]);

        // Cannot report own ad
        if ($ad->user_id === $request->user()->id) {
            return $this->errorResponse('لا يمكنك الإبلاغ عن إعلانك الخاص', 403);
        }

        // One report per user per ad
        $exists = Report::where('reporter_id', $request->user()->id)
            ->where('ad_id', $ad->id)
            ->exists();

        if ($exists) {
            return $this->errorResponse('لقد أبلغت عن هذا الإعلان مسبقاً', 409);
        }

        Report::create([
            'reporter_id' => $request->user()->id,
            'ad_id'       => $ad->id,
            'reason'      => $data['reason'],
            'description' => $data['description'] ?? null,
            'status'      => 'pending',
        ]);

        return $this->successResponse(null, 'تم إرسال البلاغ وسيتم مراجعته من قِبَل فريق الإشراف');
    }
}
