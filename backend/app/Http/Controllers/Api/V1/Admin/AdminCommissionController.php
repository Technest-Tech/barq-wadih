<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\CommissionStatus;
use App\Http\Controllers\Api\V1\BaseController;
use App\Models\CommissionPayment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AdminCommissionController extends BaseController
{
    /**
     * GET /admin/commissions
     * Paginated list with filters.
     */
    public function index(Request $request): JsonResponse
    {
        $query = CommissionPayment::with(['user:id,name,phone,avatar', 'ad:id,title,price,status,city_id'])
            ->latest();

        // ── Filters ──────────────────────────────────────────────────────
        if ($status = $request->query('status')) {
            $query->where('payment_status', $status);
        }

        if ($userId = $request->query('user_id')) {
            $query->where('user_id', $userId);
        }

        if ($q = $request->query('q')) {
            $query->whereHas('user', function ($sub) use ($q) {
                $sub->where('name', 'LIKE', "%{$q}%")
                    ->orWhere('phone', 'LIKE', "%{$q}%");
            });
        }

        if ($from = $request->query('from')) {
            $query->whereDate('created_at', '>=', $from);
        }
        if ($to = $request->query('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        if ($min = $request->query('min_amount')) {
            $query->where('commission_amount', '>=', $min);
        }
        if ($max = $request->query('max_amount')) {
            $query->where('commission_amount', '<=', $max);
        }

        // Sort
        $sortField = $request->query('sort', 'created_at');
        $sortDir   = $request->query('dir', 'desc');
        $allowed   = ['created_at', 'commission_amount', 'sale_price', 'paid_at'];
        if (in_array($sortField, $allowed)) {
            $query->orderBy($sortField, $sortDir === 'asc' ? 'asc' : 'desc');
        }

        $paginated = $query->paginate($request->integer('per_page', 20));

        // Transform
        $items = $paginated->getCollection()->map(fn (CommissionPayment $c) => [
            'id'                => $c->id,
            'user'              => $c->user ? [
                'id'     => $c->user->id,
                'name'   => $c->user->name,
                'phone'  => $c->user->phone,
                'avatar' => $c->user->avatar,
            ] : null,
            'ad'                => $c->ad ? [
                'id'     => $c->ad->id,
                'title'  => $c->ad->title,
                'price'  => $c->ad->price,
                'status' => $c->ad->status->value,
            ] : null,
            'sale_price'        => (float) $c->sale_price,
            'commission_rate'   => (float) $c->commission_rate,
            'commission_amount' => (float) $c->commission_amount,
            'is_flat_fee'       => $c->is_flat_fee,
            'status'            => $c->payment_status->value,
            'status_label'      => $c->payment_status->label(),
            'payment_method'    => $c->payment_method?->value,
            'gateway_tx_id'     => $c->gateway_transaction_id,
            'paid_at'           => $c->paid_at?->toISOString(),
            'created_at'        => $c->created_at->toISOString(),
        ]);

        return $this->successResponse([
            'data'       => $items,
            'pagination' => [
                'current_page' => $paginated->currentPage(),
                'last_page'    => $paginated->lastPage(),
                'per_page'     => $paginated->perPage(),
                'total'        => $paginated->total(),
            ],
        ]);
    }

    /**
     * GET /admin/commissions/{commission}
     */
    public function show(CommissionPayment $commission): JsonResponse
    {
        $commission->load(['user', 'ad.category', 'ad.city', 'ad.region']);

        return $this->successResponse([
            'id'                => $commission->id,
            'sale_price'        => (float) $commission->sale_price,
            'commission_rate'   => (float) $commission->commission_rate,
            'commission_amount' => (float) $commission->commission_amount,
            'is_flat_fee'       => $commission->is_flat_fee,
            'status'            => $commission->payment_status->value,
            'status_label'      => $commission->payment_status->label(),
            'payment_method'    => $commission->payment_method?->value,
            'payment_gateway'   => $commission->payment_gateway,
            'gateway_tx_id'     => $commission->gateway_transaction_id,
            'gateway_response'  => $commission->gateway_response,
            'paid_at'           => $commission->paid_at?->toISOString(),
            'created_at'        => $commission->created_at->toISOString(),
            'updated_at'        => $commission->updated_at->toISOString(),
            'user' => $commission->user ? [
                'id'          => $commission->user->id,
                'name'        => $commission->user->name,
                'phone'       => $commission->user->phone,
                'email'       => $commission->user->email,
                'avatar'      => $commission->user->avatar,
                'is_verified' => $commission->user->is_verified,
            ] : null,
            'ad' => $commission->ad ? [
                'id'       => $commission->ad->id,
                'title'    => $commission->ad->title,
                'price'    => (float) $commission->ad->price,
                'status'   => $commission->ad->status->value,
                'category' => $commission->ad->category ? [
                    'id'      => $commission->ad->category->id,
                    'name_ar' => $commission->ad->category->name_ar,
                ] : null,
                'city' => $commission->ad->city ? [
                    'id'      => $commission->ad->city->id,
                    'name_ar' => $commission->ad->city->name_ar,
                ] : null,
                'region' => $commission->ad->region ? [
                    'id'      => $commission->ad->region->id,
                    'name_ar' => $commission->ad->region->name_ar,
                ] : null,
            ] : null,
        ]);
    }

    /**
     * PATCH /admin/commissions/{commission}/status
     */
    public function updateStatus(Request $request, CommissionPayment $commission): JsonResponse
    {
        $request->validate([
            'status' => ['required', 'in:pending,paid,not_applicable'],
        ]);

        $newStatus = CommissionStatus::from($request->input('status'));

        $commission->update([
            'payment_status' => $newStatus->value,
            'paid_at'        => $newStatus === CommissionStatus::Paid ? now() : $commission->paid_at,
        ]);

        return $this->successResponse([
            'id'           => $commission->id,
            'status'       => $commission->fresh()->payment_status->value,
            'status_label' => $commission->fresh()->payment_status->label(),
            'paid_at'      => $commission->fresh()->paid_at?->toISOString(),
        ], 'تم تحديث حالة العمولة');
    }

    /**
     * GET /admin/commissions/summary
     */
    public function summary(): JsonResponse
    {
        $totalPaid    = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)->sum('commission_amount');
        $totalPending = CommissionPayment::where('payment_status', CommissionStatus::Pending->value)->sum('commission_amount');
        $thisMonth    = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)
            ->where('paid_at', '>=', now()->startOfMonth())
            ->sum('commission_amount');
        $countByStatus = [];
        foreach (CommissionStatus::cases() as $s) {
            $countByStatus[] = [
                'status' => $s->value,
                'label'  => $s->label(),
                'count'  => CommissionPayment::where('payment_status', $s->value)->count(),
            ];
        }

        $avgCommission = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)->avg('commission_amount');
        $maxCommission = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)->max('commission_amount');

        return $this->successResponse([
            'total_paid'     => (float) ($totalPaid ?? 0),
            'total_pending'  => (float) ($totalPending ?? 0),
            'this_month'     => (float) ($thisMonth ?? 0),
            'avg_commission' => (float) ($avgCommission ?? 0),
            'max_commission' => (float) ($maxCommission ?? 0),
            'total_count'    => CommissionPayment::count(),
            'by_status'      => $countByStatus,
        ]);
    }

    /**
     * GET /admin/commissions/export
     * Stream CSV download of filtered commissions.
     */
    public function export(Request $request): StreamedResponse
    {
        $query = CommissionPayment::with(['user:id,name,phone', 'ad:id,title,price'])->latest();

        if ($status = $request->query('status')) {
            $query->where('payment_status', $status);
        }
        if ($from = $request->query('from')) {
            $query->whereDate('created_at', '>=', $from);
        }
        if ($to = $request->query('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        $filename = 'commissions_' . now()->format('Y-m-d_His') . '.csv';

        return response()->streamDownload(function () use ($query) {
            $handle = fopen('php://output', 'w');

            // UTF-8 BOM for Excel Arabic support
            fwrite($handle, "\xEF\xBB\xBF");

            fputcsv($handle, [
                'ID', 'المستخدم', 'الهاتف', 'الإعلان', 'سعر البيع',
                'نسبة العمولة', 'مبلغ العمولة', 'الحالة', 'تاريخ الدفع', 'تاريخ الإنشاء',
            ]);

            $query->chunk(500, function ($commissions) use ($handle) {
                foreach ($commissions as $c) {
                    fputcsv($handle, [
                        $c->id,
                        $c->user?->name ?? '—',
                        $c->user?->phone ?? '—',
                        $c->ad?->title ?? '—',
                        $c->sale_price,
                        $c->commission_rate,
                        $c->commission_amount,
                        $c->payment_status->label(),
                        $c->paid_at?->format('Y-m-d H:i') ?? '—',
                        $c->created_at->format('Y-m-d H:i'),
                    ]);
                }
            });

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }
}
