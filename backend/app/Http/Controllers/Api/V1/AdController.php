<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Requests\Ad\StoreAdRequest;
use App\Http\Requests\Ad\UpdateAdRequest;
use App\Http\Resources\AdListResource;
use App\Http\Resources\AdResource;
use App\Http\Resources\CategoryFieldResource;
use App\Models\Ad;
use App\Models\Category;
use App\Services\AdService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdController extends BaseController
{
    public function __construct(private readonly AdService $adService) {}

    // ── Public: Ad Feed ───────────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $query = Ad::with(['images', 'category', 'city', 'region', 'user'])
            ->feed(); // scopeFeed: active + approved, boosted first

        // ── Category ──────────────────────────────────────────────────────────
        if ($request->filled('category_id')) {
            $query->where('category_id', (int) $request->input('category_id'));
        } elseif ($request->filled('category_ids')) {
            $ids = array_filter(
                array_map('intval', explode(',', $request->input('category_ids')))
            );
            if (! empty($ids)) {
                $query->whereIn('category_id', $ids);
            }
        }

        // ── Location ──────────────────────────────────────────────────────────
        if ($request->filled('city_ids')) {
            $cityIds = array_filter(
                array_map('intval', explode(',', $request->input('city_ids')))
            );
            if (! empty($cityIds)) {
                $query->whereIn('city_id', $cityIds);
            }
        } elseif ($request->filled('city_id')) {
            $query->where('city_id', (int) $request->input('city_id'));
        }
        if ($request->filled('region_id')) {
            $query->where('region_id', (int) $request->input('region_id'));
        }

        // ── Price ─────────────────────────────────────────────────────────────
        if ($request->filled('price_min')) {
            $query->where('price', '>=', (float) $request->input('price_min'));
        }
        if ($request->filled('price_max')) {
            $query->where('price', '<=', (float) $request->input('price_max'));
        }

        // ── Negotiable (على السوم) ────────────────────────────────────────────
        if ($request->boolean('negotiable')) {
            $query->where('is_negotiable', true);
        }

        // ── Full-text search ──────────────────────────────────────────────────
        if ($request->filled('q')) {
            $search = (string) $request->input('q');
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        // ── Sort ──────────────────────────────────────────────────────────────
        $sort = $request->input('sort', 'newest');
        if ($sort === 'price_asc') {
            // Ads with no price (free / negotiable / hidden) come last
            $query->reorder()
                ->orderByRaw('CASE WHEN price IS NULL THEN 1 ELSE 0 END')
                ->orderBy('price')
                ->orderByDesc('created_at');
        } elseif ($sort === 'price_desc') {
            // Ads with no price come last
            $query->reorder()
                ->orderByRaw('CASE WHEN price IS NULL THEN 1 ELSE 0 END')
                ->orderByDesc('price')
                ->orderByDesc('created_at');
        } elseif ($sort === 'oldest') {
            $query->reorder()
                ->orderBy('published_at')
                ->orderBy('created_at');
        } else {
            // newest (default)
            $query->reorder()
                ->orderByDesc('published_at')
                ->orderByDesc('created_at');
        }

        $ads = $query->paginate(20);

        return $this->paginatedResponse(
            AdListResource::collection($ads)
        );
    }

    // ── Public: Ad Detail ─────────────────────────────────────────────────────

    public function show(int $id): JsonResponse
    {
        $ad = Ad::with(['images', 'category', 'city', 'region', 'user', 'fieldValues.field'])
            ->active()
            ->findOrFail($id);

        // Increment view count (fire-and-forget)
        $ad->increment('views_count');

        return $this->successResponse(new AdResource($ad));
    }

    // ── Auth: Create Ad ───────────────────────────────────────────────────────

    public function store(StoreAdRequest $request): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        $ad = $this->adService->create(
            $user,
            $request->validated(),
            $request->file('images', [])
        );

        // Publishing is free for every category — the ad goes live immediately.
        // The flat commission is only charged after the seller marks it sold.
        return $this->successResponse([
            'ad'              => new AdResource($ad),
            'requires_payment'=> false,
            'payment_amount'  => 0.0,
            'payment_init_url'=> null,
        ], 'تم نشر الإعلان بنجاح.', 201);
    }

    // ── Auth: Update Ad ───────────────────────────────────────────────────────

    public function update(UpdateAdRequest $request, Ad $ad): JsonResponse
    {
        $this->authorize('update', $ad);

        $updated = $this->adService->update(
            $ad,
            $request->validated(),
            $request->file('images', []),
            $request->input('remove_image_ids', [])
        );

        return $this->successResponse(new AdResource($updated), 'تم تحديث الإعلان بنجاح.');
    }

    // ── Auth: Delete Ad ───────────────────────────────────────────────────────

    public function destroy(Ad $ad): JsonResponse
    {
        $this->authorize('delete', $ad);
        $this->adService->delete($ad);

        return $this->successResponse(null, 'تم حذف الإعلان بنجاح.');
    }

    // ── Auth: My Ads ──────────────────────────────────────────────────────────

    public function myAds(Request $request): JsonResponse
    {
        /** @var \App\Models\User $user */
        $user = $request->user();

        $ads = Ad::withTrashed()
            ->where('user_id', $user->id)
            ->with(['images', 'category', 'city', 'user'])
            ->latest()
            ->paginate(20);

        return $this->paginatedResponse(AdListResource::collection($ads));
    }

    // ── Auth: Mark Sold ───────────────────────────────────────────────────────

    public function markSold(Ad $ad): JsonResponse
    {
        $this->authorize('markSold', $ad);

        try {
            $this->adService->markAsSold($ad);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::error('markAsSold failed', [
                'ad_id'     => $ad->id,
                'exception' => $e->getMessage(),
                'trace'     => $e->getTraceAsString(),
            ]);
            throw $e;
        }

        $fresh = $ad->fresh(['images', 'category', 'city', 'region', 'user']);

        return $this->successResponse(
            $fresh ? new AdListResource($fresh) : null,
            'تم تحديد الإعلان كمُباع.',
        );
    }

    // ── Public: Category Fields ───────────────────────────────────────────────

    public function categoryFields(Category $category): JsonResponse
    {
        $fields = $category->fields()
            ->orderBy('sort_order')
            ->get();

        return $this->successResponse(CategoryFieldResource::collection($fields));
    }

    // ── Public: Commission Preview ────────────────────────────────────────────

    public function commissionPreview(Request $request): JsonResponse
    {
        $price      = (float) $request->input('price', 0);
        $categoryId = (int)   $request->input('category_id', 0);
        $sellerType = (string) $request->input('seller_type', 'individual');

        $amount    = $this->adService->calculateCommission($categoryId, $price, false, $sellerType);
        $isFlatFee = $this->adService->isFlatFeeCategory($categoryId, $sellerType);

        return $this->successResponse([
            'price'              => $price,
            'commission_amount'  => $amount,
            'commission_rate'    => null,
            'is_flat_fee'        => true,
            'minimum_commission' => null,
            'note'               => $amount > 0
                ? "النشر مجاني. عمولة ثابتة {$amount} ر.س (شاملة الضريبة) تُدفع بعد إتمام البيع."
                : 'النشر والعمولة مجاناً بالكامل في هذا القسم.',
        ]);
    }
}
