<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\BaseController;
use App\Models\ContactSubmission;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminContactController extends BaseController
{
    // ── GET /api/v1/admin/contact ─────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $query = ContactSubmission::with('user:id,name,email');

        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }
        if ($request->filled('category')) {
            $query->where('category', $request->input('category'));
        }
        if ($request->filled('search')) {
            $query->where(function ($q) use ($request) {
                $q->where('name', 'like', '%' . $request->input('search') . '%')
                  ->orWhere('email', 'like', '%' . $request->input('search') . '%');
            });
        }

        // Pending first, then in_progress, then resolved
        $submissions = $query
            ->orderByRaw("CASE status WHEN 'pending' THEN 1 WHEN 'in_progress' THEN 2 WHEN 'resolved' THEN 3 ELSE 4 END")
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return response()->json([
            'success' => true,
            'data'    => $submissions->items(),
            'meta'    => [
                'current_page' => $submissions->currentPage(),
                'last_page'    => $submissions->lastPage(),
                'total'        => $submissions->total(),
                'per_page'     => $submissions->perPage(),
            ],
        ]);
    }

    // ── GET /api/v1/admin/contact/{submission} ────────────────────────────────

    public function show(ContactSubmission $contactSubmission): JsonResponse
    {
        $contactSubmission->load(['user:id,name,email', 'admin:id,name']);

        return $this->successResponse($contactSubmission);
    }

    // ── PATCH /api/v1/admin/contact/{submission}/status ───────────────────────

    public function updateStatus(Request $request, ContactSubmission $contactSubmission): JsonResponse
    {
        $request->validate([
            'status'     => 'required|in:pending,in_progress,resolved',
            'admin_note' => 'nullable|string|max:1000',
        ]);

        $contactSubmission->update([
            'status'      => $request->input('status'),
            'admin_note'  => $request->input('admin_note'),
            'admin_id'    => $request->user()->id,
            'resolved_at' => $request->input('status') === 'resolved' ? now() : null,
        ]);

        return $this->successResponse($contactSubmission->fresh(), 'تم تحديث حالة الطلب بنجاح.');
    }
}
