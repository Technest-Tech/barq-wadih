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

        // Filters
        if ($request->filled('category_id')) {
            $query->where('category_id', (int) $request->input('category_id'));
        }
        if ($request->filled('city_ids')) {
            $cityIds = explode(',', $request->input('city_ids'));
            $query->whereIn('city_id', $cityIds);
        } elseif ($request->filled('city_id')) {
            $query->where('city_id', (int) $request->input('city_id'));
        }
        if ($request->filled('region_id')) {
            $query->where('region_id', (int) $request->input('region_id'));
        }
        if ($request->filled('price_min')) {
            $query->where('price', '>=', (float) $request->input('price_min'));
        }
        if ($request->filled('price_max')) {
            $query->where('price', '<=', (float) $request->input('price_max'));
        }
        if ($request->filled('q')) {
            $search = (string) $request->input('q');
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        // Sort override
        $sort = $request->input('sort', 'newest');
        if ($sort === 'price_asc') {
            $query->reorder()->orderBy('price')->orderByDesc('created_at');
        } elseif ($sort === 'price_desc') {
            $query->reorder()->orderByDesc('price')->orderByDesc('created_at');
        } else {
            // newest (default)
            $query->reorder()->orderByDesc('published_at')->orderByDesc('created_at');
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

        // Tell the wizard whether to skip straight to the ad detail page or
        // hand off to the Pay step. Frontend reads `requires_payment` first.
        $requiresPayment = $ad->payment_status === \App\Enums\PaymentStatus::Pending->value
            && (float) ($ad->payment_amount ?? 0) > 0;

        $message = $requiresPayment
            ? 'تم حفظ الإعلان — يرجى إكمال الدفع لنشره.'
            : 'تم نشر الإعلان بنجاح.';

        return $this->successResponse([
            'ad'              => new AdResource($ad),
            'requires_payment'=> $requiresPayment,
            'payment_amount'  => $requiresPayment ? (float) $ad->payment_amount : 0.0,
            'payment_init_url'=> $requiresPayment ? route('ads.payment.init', ['ad' => $ad->id]) : null,
        ], $message, 201);
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
        $this->adService->markAsSold($ad);

        return $this->successResponse(new AdListResource($ad->fresh()), 'تم تحديد الإعلان كمُباع.');
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
        $price  = (float) $request->input('price', 0);
        $isFree = (bool) $request->input('is_free', false);

        $amount = $this->adService->calculateCommission($price, $isFree);

        return $this->successResponse([
            'price'             => $price,
            'is_free'           => $isFree,
            'commission_amount' => $amount,
            'commission_rate'   => '0.5%',
            'minimum_commission'=> 90.0,
            'note'              => $isFree || $price <= 0
                ? 'لا توجد عمولة للإعلانات المجانية'
                : 'العمولة = الأعلى بين 90 ر.س أو 0.5% من السعر',
        ]);
    }
}
