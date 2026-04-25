<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\CommissionStatus;
use App\Http\Controllers\Api\V1\BaseController;
use App\Models\Ad;
use App\Models\CommissionPayment;
use App\Models\SearchLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminAnalyticsController extends BaseController
{
    /**
     * GET /admin/analytics/revenue
     *
     * Revenue time series. Accepts ?period=7d|30d|90d|1y
     */
    public function revenue(Request $request): JsonResponse
    {
        $period = $request->query('period', '30d');

        [$days, $grouping] = match ($period) {
            '7d'  => [7, 'daily'],
            '30d' => [30, 'daily'],
            '90d' => [90, 'weekly'],
            '1y'  => [365, 'monthly'],
            default => [30, 'daily'],
        };

        $startDate = now()->subDays($days)->startOfDay();

        if ($grouping === 'daily') {
            $series = [];
            for ($i = $days - 1; $i >= 0; $i--) {
                $date = now()->subDays($i);
                $revenue = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)
                    ->whereDate('paid_at', $date->toDateString())
                    ->sum('commission_amount');
                $series[] = [
                    'label'   => $date->format('M d'),
                    'date'    => $date->toDateString(),
                    'revenue' => (float) $revenue,
                ];
            }
        } elseif ($grouping === 'weekly') {
            $series = [];
            $weeks = (int) ceil($days / 7);
            for ($i = $weeks - 1; $i >= 0; $i--) {
                $weekStart = now()->subWeeks($i)->startOfWeek();
                $weekEnd   = now()->subWeeks($i)->endOfWeek();
                $revenue = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)
                    ->whereBetween('paid_at', [$weekStart, $weekEnd])
                    ->sum('commission_amount');
                $series[] = [
                    'label'   => $weekStart->format('M d'),
                    'date'    => $weekStart->toDateString(),
                    'revenue' => (float) $revenue,
                ];
            }
        } else {
            $series = [];
            $months = (int) ceil($days / 30);
            for ($i = $months - 1; $i >= 0; $i--) {
                $monthStart = now()->subMonths($i)->startOfMonth();
                $monthEnd   = now()->subMonths($i)->endOfMonth();
                $revenue = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)
                    ->whereBetween('paid_at', [$monthStart, $monthEnd])
                    ->sum('commission_amount');
                $series[] = [
                    'label'   => $monthStart->translatedFormat('M Y'),
                    'date'    => $monthStart->toDateString(),
                    'revenue' => (float) $revenue,
                ];
            }
        }

        // Summary for the period
        $totalInPeriod = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)
            ->where('paid_at', '>=', $startDate)
            ->sum('commission_amount');
        $countInPeriod = CommissionPayment::where('payment_status', CommissionStatus::Paid->value)
            ->where('paid_at', '>=', $startDate)
            ->count();

        return $this->successResponse([
            'period'         => $period,
            'grouping'       => $grouping,
            'series'         => $series,
            'total_revenue'  => (float) $totalInPeriod,
            'total_transactions' => $countInPeriod,
        ]);
    }

    /**
     * GET /admin/analytics/ads-by-city
     * Top 20 cities by ad count.
     */
    public function adsByCity(): JsonResponse
    {
        $data = Ad::select('city_id', DB::raw('COUNT(*) as ad_count'))
            ->whereNotNull('city_id')
            ->groupBy('city_id')
            ->orderByDesc('ad_count')
            ->limit(20)
            ->with('city:id,name_ar,region_id', 'city.region:id,name_ar')
            ->get()
            ->map(fn (Ad $ad) => [
                'city_id'     => $ad->city_id,
                'city_name'   => $ad->city?->name_ar ?? '—',
                'region_name' => $ad->city?->region?->name_ar ?? '—',
                'ad_count'    => $ad->ad_count,
            ]);

        return $this->successResponse($data);
    }

    /**
     * GET /admin/analytics/search-terms
     * Top searched keywords (last 90 days).
     */
    public function searchTerms(Request $request): JsonResponse
    {
        $days  = $request->integer('days', 90);
        $limit = $request->integer('limit', 30);

        $terms = SearchLog::select(
                'query',
                DB::raw('COUNT(*) as search_count'),
                DB::raw('AVG(results_count) as avg_results'),
                DB::raw('MAX(created_at) as last_searched')
            )
            ->where('created_at', '>=', now()->subDays($days))
            ->whereNotNull('query')
            ->where('query', '!=', '')
            ->groupBy('query')
            ->orderByDesc('search_count')
            ->limit($limit)
            ->get()
            ->map(fn ($row) => [
                'query'         => $row->query,
                'search_count'  => (int) $row->search_count,
                'avg_results'   => round((float) ($row->avg_results ?? 0), 1),
                'last_searched' => $row->last_searched,
            ]);

        // Daily search volume for chart
        $dailyVolume = [];
        $chartDays = min($days, 30);
        for ($i = $chartDays - 1; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $dailyVolume[] = [
                'date'  => $date->toDateString(),
                'label' => $date->format('M d'),
                'count' => SearchLog::whereDate('created_at', $date->toDateString())->count(),
            ];
        }

        // Platform breakdown
        $platforms = SearchLog::select('platform', DB::raw('COUNT(*) as count'))
            ->where('created_at', '>=', now()->subDays($days))
            ->groupBy('platform')
            ->get()
            ->map(fn ($row) => [
                'platform' => $row->platform?->value ?? 'unknown',
                'count'    => (int) $row->count,
            ]);

        return $this->successResponse([
            'terms'         => $terms,
            'daily_volume'  => $dailyVolume,
            'platforms'     => $platforms,
            'total_searches' => SearchLog::where('created_at', '>=', now()->subDays($days))->count(),
        ]);
    }

    /**
     * GET /admin/analytics/zero-results
     * Queries that returned 0 results — content gap indicator.
     */
    public function zeroResults(Request $request): JsonResponse
    {
        $days  = $request->integer('days', 90);
        $limit = $request->integer('limit', 30);

        $terms = SearchLog::select(
                'query',
                DB::raw('COUNT(*) as search_count'),
                DB::raw('MAX(created_at) as last_searched')
            )
            ->zeroResults()
            ->where('created_at', '>=', now()->subDays($days))
            ->whereNotNull('query')
            ->where('query', '!=', '')
            ->groupBy('query')
            ->orderByDesc('search_count')
            ->limit($limit)
            ->get()
            ->map(fn ($row) => [
                'query'         => $row->query,
                'search_count'  => (int) $row->search_count,
                'last_searched' => $row->last_searched,
            ]);

        return $this->successResponse([
            'terms'       => $terms,
            'total_zero'  => SearchLog::zeroResults()->where('created_at', '>=', now()->subDays($days))->count(),
        ]);
    }
}
