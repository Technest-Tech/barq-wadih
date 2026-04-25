<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\AdStatus;
use App\Enums\CommissionStatus;
use App\Enums\ReportStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\BaseController;
use App\Http\Resources\AdListResource;
use App\Models\Ad;
use App\Models\Banner;
use App\Models\CommissionPayment;
use App\Models\Report;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class DashboardController extends BaseController
{
    /**
     * GET /api/v1/admin/dashboard/stats
     *
     * Aggregated KPI data for the admin dashboard.
     */
    public function stats(): JsonResponse
    {
        // ── User KPIs ────────────────────────────────────────────────────
        $totalUsers      = User::count();
        $activeUsers     = User::where('is_active', true)->count();
        $verifiedUsers   = User::where('is_verified', true)->count();
        $dealerUsers     = User::where('is_dealer', true)->count();
        $newUsersToday   = User::whereDate('created_at', today())->count();
        $newUsersWeek    = User::where('created_at', '>=', now()->startOfWeek())->count();
        $newUsersMonth   = User::where('created_at', '>=', now()->startOfMonth())->count();

        // Previous month for trend comparison
        $prevMonthStart = now()->subMonth()->startOfMonth();
        $prevMonthEnd   = now()->subMonth()->endOfMonth();
        $newUsersPrevMonth = User::whereBetween('created_at', [$prevMonthStart, $prevMonthEnd])->count();

        // Users by role
        $usersByRole = [];
        foreach (UserRole::cases() as $role) {
            $usersByRole[] = [
                'role'  => $role->value,
                'label' => $role->label(),
                'count' => User::where('role', $role->value)->count(),
            ];
        }

        // ── Ad KPIs ─────────────────────────────────────────────────────
        $totalAds  = Ad::count();
        $activeAds = Ad::where('status', AdStatus::Active->value)->count();
        $newAdsToday = Ad::whereDate('created_at', today())->count();
        $newAdsWeek  = Ad::where('created_at', '>=', now()->startOfWeek())->count();

        // Ads by status
        $adsByStatus = [];
        foreach (AdStatus::cases() as $status) {
            $adsByStatus[] = [
                'status' => $status->value,
                'label'  => $status->label(),
                'count'  => Ad::where('status', $status->value)->count(),
            ];
        }

        // ── Revenue KPIs ────────────────────────────────────────────────
        $totalRevenue = CommissionPayment::where('status', CommissionStatus::Paid->value)
            ->sum('amount');
        $revenueThisMonth = CommissionPayment::where('status', CommissionStatus::Paid->value)
            ->where('paid_at', '>=', now()->startOfMonth())
            ->sum('amount');
        $revenuePrevMonth = CommissionPayment::where('status', CommissionStatus::Paid->value)
            ->whereBetween('paid_at', [$prevMonthStart, $prevMonthEnd])
            ->sum('amount');
        $pendingCommissions = CommissionPayment::where('status', CommissionStatus::Due->value)
            ->sum('amount');

        // ── Other KPIs ──────────────────────────────────────────────────
        $activeBanners  = Banner::where('is_active', true)->count();
        $pendingReports = Report::where('status', ReportStatus::Pending->value)->count();

        // ── Recent Activity ─────────────────────────────────────────────
        $recentAds = Ad::with(['user:id,name,avatar', 'category:id,name_ar,name_en', 'city:id,name_ar,name_en'])
            ->latest()
            ->limit(10)
            ->get();

        // ── Weekly user registrations (last 12 weeks) ───────────────────
        $weeklyRegistrations = [];
        for ($i = 11; $i >= 0; $i--) {
            $weekStart = now()->subWeeks($i)->startOfWeek();
            $weekEnd   = now()->subWeeks($i)->endOfWeek();
            $weeklyRegistrations[] = [
                'week'  => $weekStart->format('M d'),
                'count' => User::whereBetween('created_at', [$weekStart, $weekEnd])->count(),
            ];
        }

        // ── Monthly revenue (last 6 months) ─────────────────────────────
        $monthlyRevenue = [];
        for ($i = 5; $i >= 0; $i--) {
            $monthStart = now()->subMonths($i)->startOfMonth();
            $monthEnd   = now()->subMonths($i)->endOfMonth();
            $monthlyRevenue[] = [
                'month'   => $monthStart->translatedFormat('M Y'),
                'revenue' => (float) CommissionPayment::where('status', CommissionStatus::Paid->value)
                    ->whereBetween('paid_at', [$monthStart, $monthEnd])
                    ->sum('amount'),
            ];
        }

        return $this->successResponse([
            'users' => [
                'total'           => $totalUsers,
                'active'          => $activeUsers,
                'verified'        => $verifiedUsers,
                'dealers'         => $dealerUsers,
                'new_today'       => $newUsersToday,
                'new_this_week'   => $newUsersWeek,
                'new_this_month'  => $newUsersMonth,
                'new_prev_month'  => $newUsersPrevMonth,
                'by_role'         => $usersByRole,
                'weekly_registrations' => $weeklyRegistrations,
            ],
            'ads' => [
                'total'         => $totalAds,
                'active'        => $activeAds,
                'new_today'     => $newAdsToday,
                'new_this_week' => $newAdsWeek,
                'by_status'     => $adsByStatus,
            ],
            'revenue' => [
                'total'              => (float) $totalRevenue,
                'this_month'         => (float) $revenueThisMonth,
                'prev_month'         => (float) $revenuePrevMonth,
                'pending_commissions' => (float) $pendingCommissions,
                'monthly'            => $monthlyRevenue,
            ],
            'banners' => [
                'active' => $activeBanners,
            ],
            'reports' => [
                'pending' => $pendingReports,
            ],
            'recent_ads' => AdListResource::collection($recentAds),
        ]);
    }
}
