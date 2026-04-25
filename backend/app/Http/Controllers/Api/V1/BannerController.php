<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\BannerLinkType;
use App\Enums\BannerPosition;
use App\Http\Resources\BannerResource;
use App\Models\Banner;
use App\Models\BannerClick;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Enum;

class BannerController extends BaseController
{
    // ── Public: Active Banners for a Position ──────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'position' => ['required', new Enum(BannerPosition::class)],
        ]);

        $position = BannerPosition::from($request->input('position'));

        $banners = Banner::currentlyActive($position)
            ->orderBy('sort_order')
            ->get();

        // Fire-and-forget: batch-increment impressions for all returned banners
        if ($banners->isNotEmpty()) {
            Banner::whereIn('id', $banners->pluck('id'))
                ->increment('impressions_count');
        }

        return $this->successResponse(BannerResource::collection($banners));
    }

    // ── Public: Record Click ──────────────────────────────────────────────────

    public function click(Request $request, Banner $banner): JsonResponse
    {
        if (! $banner->isLive()) {
            return $this->errorResponse('هذا الإعلان غير نشط حالياً.', 410);
        }

        // Record click
        BannerClick::create([
            'banner_id'  => $banner->id,
            'user_id'    => $request->user()?->id,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'platform'   => $request->header('X-Platform', 'web'),
            'clicked_at' => now(),
        ]);

        // Increment counter
        $banner->increment('clicks_count');

        // Resolve redirect URL based on link type
        $redirectUrl = match ($banner->link_type) {
            BannerLinkType::Ad       => $banner->link_ad_id ? "/ads/{$banner->link_ad_id}" : null,
            BannerLinkType::Whatsapp => $banner->link_whatsapp ? "https://wa.me/{$banner->link_whatsapp}" : null,
            BannerLinkType::Url      => $banner->link_url,
            default                  => null,
        };

        return $this->successResponse([
            'redirect_url' => $redirectUrl,
        ]);
    }
}
