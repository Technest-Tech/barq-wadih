<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\AdListResource;
use App\Models\Ad;
use App\Models\SearchLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class SearchController extends BaseController
{
    // ── Public: Full-text Ad Search ───────────────────────────────────────────

    /**
     * GET /api/v1/search
     *
     * Supports:
     *   ?q=         — search query (Arabic / English)
     *   &category_id=
     *   &city_id=
     *   &region_id=
     *   &price_min=
     *   &price_max=
     *   &is_free=1
     *   &sort=newest|price_asc|price_desc|relevance
     *   &page=
     *
     * Uses Meilisearch when SCOUT_DRIVER=meilisearch; falls back gracefully
     * to MySQL LIKE search when running without Docker / Meilisearch.
     */
    public function index(Request $request): JsonResponse
    {
        $q          = (string) $request->input('q', '');
        $categoryId = $request->filled('category_id') ? (int) $request->input('category_id') : null;
        $cityId     = $request->filled('city_id')     ? (int) $request->input('city_id')     : null;
        $regionId   = $request->filled('region_id')   ? (int) $request->input('region_id')   : null;
        $priceMin   = $request->filled('price_min')   ? (float) $request->input('price_min') : null;
        $priceMax   = $request->filled('price_max')   ? (float) $request->input('price_max') : null;
        $isFree     = $request->boolean('is_free');
        $sort       = $request->input('sort', $q ? 'relevance' : 'newest');

        $driver = config('scout.driver', 'collection');
        $useMeilisearch = $driver === 'meilisearch';

        if ($useMeilisearch && $q !== '') {
            $ads = $this->searchViaMeilisearch(
                $q, $categoryId, $cityId, $regionId, $priceMin, $priceMax, $isFree, $sort
            );
        } else {
            $ads = $this->searchViaEloquent(
                $q, $categoryId, $cityId, $regionId, $priceMin, $priceMax, $isFree, $sort
            );
        }

        // ── SearchLog (fire-and-forget) ───────────────────────────────────────
        $this->logSearch($request, $q, $categoryId, $cityId, $ads->total());

        return $this->paginatedResponse(AdListResource::collection($ads));
    }

    // ── Private: Meilisearch path ─────────────────────────────────────────────

    /** @return \Illuminate\Contracts\Pagination\LengthAwarePaginator */
    private function searchViaMeilisearch(
        string $q,
        ?int $categoryId,
        ?int $cityId,
        ?int $regionId,
        ?float $priceMin,
        ?float $priceMax,
        bool $isFree,
        string $sort
    ) {
        try {
            $builder = Ad::search($q, function ($engine, $query, $options) use (
                $categoryId, $cityId, $regionId, $priceMin, $priceMax, $isFree, $sort
            ) {
                // ── Build Meilisearch filter expression ───────────────────────
                $filters = ['status = "active"'];

                if ($categoryId !== null) {
                    $filters[] = "category_id = {$categoryId}";
                }
                if ($cityId !== null) {
                    $filters[] = "city_id = {$cityId}";
                }
                if ($regionId !== null) {
                    $filters[] = "region_id = {$regionId}";
                }
                if ($isFree) {
                    $filters[] = 'is_free = 1';
                }
                if ($priceMin !== null) {
                    $filters[] = "price >= {$priceMin}";
                }
                if ($priceMax !== null) {
                    $filters[] = "price <= {$priceMax}";
                }

                $options['filter'] = implode(' AND ', $filters);

                // ── Sort ──────────────────────────────────────────────────────
                $options['sort'] = match ($sort) {
                    'price_asc'  => ['price:asc'],
                    'price_desc' => ['price:desc'],
                    'newest'     => ['published_at:desc'],
                    default      => ['is_boosted:desc', 'published_at:desc'],
                };

                $options['limit'] = 20;

                return $engine->search($query, $options);
            });

            // Eager-load Eloquent relations on the matching IDs
            $builder->query(fn ($q) => $q->with(['images', 'category', 'city', 'region']));

            return $builder->paginate(20);
        } catch (\Throwable $e) {
            // Meilisearch unavailable — fall back silently
            Log::warning('Meilisearch search failed, falling back to Eloquent', [
                'error' => $e->getMessage(),
                'query' => $q,
            ]);

            return $this->searchViaEloquent(
                $q, $categoryId, $cityId, $regionId, $priceMin, $priceMax, $isFree, $sort
            );
        }
    }

    // ── Private: Eloquent fallback path ───────────────────────────────────────

    /** @return \Illuminate\Contracts\Pagination\LengthAwarePaginator */
    private function searchViaEloquent(
        string $q,
        ?int $categoryId,
        ?int $cityId,
        ?int $regionId,
        ?float $priceMin,
        ?float $priceMax,
        bool $isFree,
        string $sort
    ) {
        $query = Ad::with(['images', 'category', 'city', 'region'])->feed();

        if ($q !== '') {
            $query->where(function ($sub) use ($q) {
                $sub->where('title', 'like', "%{$q}%")
                    ->orWhere('description', 'like', "%{$q}%");
            });
        }

        if ($categoryId !== null) {
            $query->where('category_id', $categoryId);
        }
        if ($cityId !== null) {
            $query->where('city_id', $cityId);
        }
        if ($regionId !== null) {
            $query->where('region_id', $regionId);
        }
        if ($isFree) {
            $query->where('is_free', true);
        }
        if ($priceMin !== null) {
            $query->where('price', '>=', $priceMin);
        }
        if ($priceMax !== null) {
            $query->where('price', '<=', $priceMax);
        }

        // Sort
        match ($sort) {
            'price_asc'  => $query->reorder()->orderBy('price'),
            'price_desc' => $query->reorder()->orderByDesc('price'),
            'newest'     => $query->reorder()->orderByDesc('published_at'),
            default      => null, // Keep scopeFeed ordering (boosted first, then newest)
        };

        return $query->paginate(20);
    }

    // ── Private: Logging ──────────────────────────────────────────────────────

    private function logSearch(Request $request, string $q, ?int $categoryId, ?int $cityId, int $total): void
    {
        if ($q === '') {
            return; // Don't log empty/filter-only queries
        }

        try {
            $platform = match (true) {
                str_contains($request->userAgent() ?? '', 'Flutter') => 'android',
                str_contains($request->userAgent() ?? '', 'iPhone')  => 'ios',
                default => 'web',
            };

            SearchLog::create([
                'user_id'       => $request->user()?->id,
                'query'         => mb_substr($q, 0, 255),
                'category_id'   => $categoryId,
                'city_id'       => $cityId,
                'results_count' => $total,
                'platform'      => $platform,
            ]);
        } catch (\Throwable) {
            // Logging should never fail the search request
        }
    }
}
