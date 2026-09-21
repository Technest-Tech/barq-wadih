<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\BaseController;
use App\Http\Resources\AdminUserDetailResource;
use App\Http\Resources\AdminUserResource;
use App\Models\User;
use App\Services\PushService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminUserController extends BaseController
{
    /**
     * GET /api/v1/admin/users
     *
     * Paginated user list with search, filter, and sort.
     */
    public function index(Request $request): JsonResponse
    {
        $query = User::with(['region', 'city']);

        // ── Search (name, email, phone) ──────────────────────────────────
        if ($q = $request->input('q')) {
            $query->where(function ($builder) use ($q) {
                $builder->where('name', 'LIKE', "%{$q}%")
                    ->orWhere('email', 'LIKE', "%{$q}%")
                    ->orWhere('phone', 'LIKE', "%{$q}%");
            });
        }

        // ── Filters ─────────────────────────────────────────────────────
        if ($request->filled('role')) {
            $query->where('role', $request->input('role'));
        }

        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->input('is_active'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->has('is_verified')) {
            $query->where('is_verified', filter_var($request->input('is_verified'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->has('is_dealer')) {
            $query->where('is_dealer', filter_var($request->input('is_dealer'), FILTER_VALIDATE_BOOLEAN));
        }

        if ($request->filled('region_id')) {
            $query->where('region_id', $request->input('region_id'));
        }

        if ($request->filled('city_id')) {
            $query->where('city_id', $request->input('city_id'));
        }

        // ── Sort ────────────────────────────────────────────────────────
        $sortField = $request->input('sort', 'created_at');
        $sortDir   = $request->input('dir', 'desc');

        $allowedSorts = ['created_at', 'name', 'total_ads_count', 'avg_rating', 'last_active_at'];
        if (! in_array($sortField, $allowedSorts)) {
            $sortField = 'created_at';
        }

        $query->orderBy($sortField, $sortDir === 'asc' ? 'asc' : 'desc');

        // ── Paginate ────────────────────────────────────────────────────
        $perPage = min((int) $request->input('per_page', 20), 100);
        $users   = $query->paginate($perPage);

        return $this->paginatedResponse(
            AdminUserResource::collection($users)
        );
    }

    /**
     * GET /api/v1/admin/users/{user}
     *
     * Full user detail with nested relationships.
     */
    public function show(User $user): JsonResponse
    {
        $user->load([
            'region',
            'city',
            'verifiedBy:id,name',
            'ads'                => fn ($q) => $q->with(['category:id,name_ar,name_en', 'city:id,name_ar,name_en'])->latest()->limit(20),
            'commissionPayments' => fn ($q) => $q->latest()->limit(20),
            'ratingsReceived'    => fn ($q) => $q->with('rater:id,name')->latest()->limit(20),
            'devices',
        ]);

        return $this->successResponse(
            new AdminUserDetailResource($user)
        );
    }

    /**
     * PATCH /api/v1/admin/users/{user}/status
     *
     * Toggle user active status.
     */
    public function updateStatus(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'is_active' => ['required', 'boolean'],
        ]);

        // Prevent admin from deactivating themselves
        if ($user->id === $request->user()->id && ! $validated['is_active']) {
            return $this->errorResponse('لا يمكنك تعطيل حسابك الخاص', 422);
        }

        $user->update(['is_active' => $validated['is_active']]);

        return $this->successResponse(
            new AdminUserResource($user->load(['region', 'city'])),
            $validated['is_active'] ? 'تم تفعيل الحساب بنجاح' : 'تم تعطيل الحساب بنجاح'
        );
    }

    /**
     * PATCH /api/v1/admin/users/{user}/verification
     *
     * Grant or revoke the seller's verification badge. Sellers pay for the
     * badge outside the app, so only a super_admin may hand it out, and every
     * grant records who did it and against which payment.
     */
    public function updateVerification(Request $request, User $user): JsonResponse
    {
        if (! $request->user()->isSuperAdmin()) {
            return $this->errorResponse('صلاحيات المشرف العام مطلوبة لمنح شارة التوثيق', 403);
        }

        $validated = $request->validate([
            'is_verified' => ['required', 'boolean'],
            'note'        => ['nullable', 'string', 'max:500'],
        ]);

        $granting = $validated['is_verified'];

        $user->update([
            'is_verified'       => $granting,
            // Keep the trail pointing at the most recent decision either way:
            // a revoke clears the grant rather than leaving a stale one behind.
            'verified_at'       => $granting ? now() : null,
            'verified_by'       => $granting ? $request->user()->id : null,
            'verification_note' => $validated['note'] ?? null,
        ]);

        if ($granting) {
            app(PushService::class)->sendToUser(
                $user->id,
                'account_verified',
                'تم توثيق حسابك',
                'تهانينا! أصبح حسابك موثقاً وستظهر شارة التوثيق على ملفك وإعلاناتك.',
                ['type' => 'verification', 'user_id' => $user->id],
            );
        }

        return $this->successResponse(
            new AdminUserResource($user->load(['region', 'city', 'verifiedBy:id,name'])),
            $granting ? 'تم منح شارة التوثيق بنجاح' : 'تم سحب شارة التوثيق'
        );
    }

    /**
     * PATCH /api/v1/admin/users/{user}/role
     *
     * Change user role. Requires super_admin.
     */
    public function updateRole(Request $request, User $user): JsonResponse
    {
        // Only super_admin can change roles
        if (! $request->user()->isSuperAdmin()) {
            return $this->errorResponse('صلاحيات المشرف العام مطلوبة لتغيير الأدوار', 403);
        }

        $validated = $request->validate([
            'role' => ['required', Rule::in(array_column(UserRole::cases(), 'value'))],
        ]);

        // Prevent super_admin from demoting themselves
        if ($user->id === $request->user()->id) {
            return $this->errorResponse('لا يمكنك تغيير صلاحياتك الخاصة', 422);
        }

        $user->update(['role' => $validated['role']]);

        return $this->successResponse(
            new AdminUserResource($user->load(['region', 'city'])),
            'تم تحديث صلاحيات المستخدم بنجاح'
        );
    }
}
