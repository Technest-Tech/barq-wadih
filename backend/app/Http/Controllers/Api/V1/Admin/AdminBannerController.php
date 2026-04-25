<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\BannerPosition;
use App\Http\Controllers\Api\V1\BaseController;
use App\Models\Banner;
use App\Models\BannerClick;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class AdminBannerController extends BaseController
{
    /**
     * GET /admin/banners
     */
    public function index(Request $request): JsonResponse
    {
        $query = Banner::latest();

        if ($position = $request->query('position')) {
            $query->where('position', $position);
        }

        if ($request->query('status') === 'active') {
            $query->where('is_active', true)->where('ends_at', '>', now());
        } elseif ($request->query('status') === 'inactive') {
            $query->where('is_active', false);
        } elseif ($request->query('status') === 'expired') {
            $query->where('ends_at', '<=', now());
        }

        if ($q = $request->query('q')) {
            $query->where(function ($sub) use ($q) {
                $sub->where('title', 'LIKE', "%{$q}%")
                    ->orWhere('advertiser_name', 'LIKE', "%{$q}%");
            });
        }

        $paginated = $query->paginate($request->integer('per_page', 20));

        $items = $paginated->getCollection()->map(fn (Banner $b) => [
            'id'                => $b->id,
            'title'             => $b->title,
            'image_url'         => $b->image_url,
            'image_url_mobile'  => $b->image_url_mobile,
            'link_type'         => $b->link_type->value,
            'link_type_label'   => $b->link_type->label(),
            'position'          => $b->position->value,
            'position_label'    => $b->position->label(),
            'sort_order'        => $b->sort_order,
            'is_active'         => $b->is_active,
            'is_live'           => $b->isLive(),
            'starts_at'         => $b->starts_at?->toISOString(),
            'ends_at'           => $b->ends_at?->toISOString(),
            'impressions_count' => $b->impressions_count,
            'clicks_count'      => $b->clicks_count,
            'ctr'               => $b->getCtr(),
            'advertiser_name'   => $b->advertiser_name,
            'created_at'        => $b->created_at->toISOString(),
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
     * POST /admin/banners
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title'            => ['required', 'string', 'max:255'],
            'image'            => ['nullable', 'image', 'max:5120'], // 5MB
            'image_mobile'     => ['nullable', 'image', 'max:3072'], // 3MB
            'image_url'        => ['nullable', 'url'],
            'image_url_mobile' => ['nullable', 'url'],
            'link_type'        => ['required', 'in:ad,whatsapp,url,none'],
            'link_ad_id'       => ['nullable', 'integer', 'exists:ads,id'],
            'link_whatsapp'    => ['nullable', 'string', 'max:20'],
            'link_url'         => ['nullable', 'url'],
            'position'         => ['required', 'in:home_top,home_middle,category_top'],
            'sort_order'       => ['nullable', 'integer', 'min:0'],
            'starts_at'        => ['required', 'date'],
            'ends_at'          => ['required', 'date', 'after:starts_at'],
            'is_active'        => ['nullable', 'boolean'],
            'advertiser_name'  => ['nullable', 'string', 'max:255'],
            'advertiser_phone' => ['nullable', 'string', 'max:20'],
            'notes'            => ['nullable', 'string', 'max:1000'],
        ]);

        // Handle image uploads
        $imageUrl       = $validated['image_url'] ?? null;
        $imageUrlMobile = $validated['image_url_mobile'] ?? null;

        if ($request->hasFile('image')) {
            $imageUrl = $this->uploadBannerImage($request->file('image'), 'desktop');
        }
        if ($request->hasFile('image_mobile')) {
            $imageUrlMobile = $this->uploadBannerImage($request->file('image_mobile'), 'mobile');
        }

        $banner = Banner::create([
            'title'             => $validated['title'],
            'image_url'         => $imageUrl,
            'image_url_mobile'  => $imageUrlMobile,
            'link_type'         => $validated['link_type'],
            'link_ad_id'        => $validated['link_ad_id'] ?? null,
            'link_whatsapp'     => $validated['link_whatsapp'] ?? null,
            'link_url'          => $validated['link_url'] ?? null,
            'position'          => $validated['position'],
            'sort_order'        => $validated['sort_order'] ?? 0,
            'starts_at'         => $validated['starts_at'],
            'ends_at'           => $validated['ends_at'],
            'is_active'         => $validated['is_active'] ?? true,
            'advertiser_name'   => $validated['advertiser_name'] ?? null,
            'advertiser_phone'  => $validated['advertiser_phone'] ?? null,
            'notes'             => $validated['notes'] ?? null,
            'impressions_count' => 0,
            'clicks_count'      => 0,
        ]);

        return $this->successResponse(['id' => $banner->id], 'تم إنشاء البانر بنجاح', 201);
    }

    /**
     * GET /admin/banners/{banner}
     */
    public function show(Banner $banner): JsonResponse
    {
        $banner->load('linkedAd:id,title,price');

        return $this->successResponse([
            'id'                => $banner->id,
            'title'             => $banner->title,
            'image_url'         => $banner->image_url,
            'image_url_mobile'  => $banner->image_url_mobile,
            'link_type'         => $banner->link_type->value,
            'link_type_label'   => $banner->link_type->label(),
            'link_ad_id'        => $banner->link_ad_id,
            'linked_ad'         => $banner->linkedAd ? ['id' => $banner->linkedAd->id, 'title' => $banner->linkedAd->title] : null,
            'link_whatsapp'     => $banner->link_whatsapp,
            'link_url'          => $banner->link_url,
            'position'          => $banner->position->value,
            'position_label'    => $banner->position->label(),
            'sort_order'        => $banner->sort_order,
            'is_active'         => $banner->is_active,
            'is_live'           => $banner->isLive(),
            'starts_at'         => $banner->starts_at?->toISOString(),
            'ends_at'           => $banner->ends_at?->toISOString(),
            'impressions_count' => $banner->impressions_count,
            'clicks_count'      => $banner->clicks_count,
            'ctr'               => $banner->getCtr(),
            'advertiser_name'   => $banner->advertiser_name,
            'advertiser_phone'  => $banner->advertiser_phone,
            'notes'             => $banner->notes,
            'created_at'        => $banner->created_at->toISOString(),
            'updated_at'        => $banner->updated_at->toISOString(),
        ]);
    }

    /**
     * PUT /admin/banners/{banner}
     */
    public function update(Request $request, Banner $banner): JsonResponse
    {
        $validated = $request->validate([
            'title'            => ['sometimes', 'string', 'max:255'],
            'image'            => ['nullable', 'image', 'max:5120'],
            'image_mobile'     => ['nullable', 'image', 'max:3072'],
            'image_url'        => ['nullable', 'url'],
            'image_url_mobile' => ['nullable', 'url'],
            'link_type'        => ['sometimes', 'in:ad,whatsapp,url,none'],
            'link_ad_id'       => ['nullable', 'integer', 'exists:ads,id'],
            'link_whatsapp'    => ['nullable', 'string', 'max:20'],
            'link_url'         => ['nullable', 'url'],
            'position'         => ['sometimes', 'in:home_top,home_middle,category_top'],
            'sort_order'       => ['nullable', 'integer', 'min:0'],
            'starts_at'        => ['sometimes', 'date'],
            'ends_at'          => ['sometimes', 'date'],
            'is_active'        => ['nullable', 'boolean'],
            'advertiser_name'  => ['nullable', 'string', 'max:255'],
            'advertiser_phone' => ['nullable', 'string', 'max:20'],
            'notes'            => ['nullable', 'string', 'max:1000'],
        ]);

        if ($request->hasFile('image')) {
            $validated['image_url'] = $this->uploadBannerImage($request->file('image'), 'desktop');
        }
        if ($request->hasFile('image_mobile')) {
            $validated['image_url_mobile'] = $this->uploadBannerImage($request->file('image_mobile'), 'mobile');
        }

        // Remove file fields before mass update
        unset($validated['image'], $validated['image_mobile']);

        $banner->update($validated);

        return $this->successResponse(['id' => $banner->id], 'تم تحديث البانر');
    }

    /**
     * DELETE /admin/banners/{banner}
     */
    public function destroy(Banner $banner): JsonResponse
    {
        $banner->clicks()->delete();
        $banner->delete();

        return $this->successResponse(null, 'تم حذف البانر');
    }

    /**
     * POST /admin/banners/{banner}/toggle
     */
    public function toggle(Banner $banner): JsonResponse
    {
        $banner->update(['is_active' => !$banner->is_active]);

        return $this->successResponse([
            'id'        => $banner->id,
            'is_active' => $banner->fresh()->is_active,
        ], $banner->fresh()->is_active ? 'تم تفعيل البانر' : 'تم إيقاف البانر');
    }

    /**
     * GET /admin/banners/{banner}/analytics
     */
    public function analytics(Banner $banner): JsonResponse
    {
        // Daily clicks over last 30 days
        $dailyClicks = [];
        for ($i = 29; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $dailyClicks[] = [
                'date'  => $date->toDateString(),
                'label' => $date->format('M d'),
                'count' => BannerClick::where('banner_id', $banner->id)
                    ->whereDate('clicked_at', $date->toDateString())
                    ->count(),
            ];
        }

        // Platform breakdown
        $platforms = BannerClick::where('banner_id', $banner->id)
            ->select('platform', DB::raw('COUNT(*) as count'))
            ->groupBy('platform')
            ->get()
            ->map(fn ($row) => [
                'platform' => $row->platform?->value ?? 'unknown',
                'count'    => (int) $row->count,
            ]);

        return $this->successResponse([
            'impressions'  => $banner->impressions_count,
            'clicks'       => $banner->clicks_count,
            'ctr'          => $banner->getCtr(),
            'daily_clicks' => $dailyClicks,
            'platforms'    => $platforms,
        ]);
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private function uploadBannerImage($file, string $variant): string
    {
        $disk = config('filesystems.default') === 'do_spaces' ? 'do_spaces' : 'public';
        $path = $file->store("banners/{$variant}", $disk);

        if ($disk === 'public') {
            return asset("storage/{$path}");
        }

        return Storage::disk($disk)->url($path);
    }
}
