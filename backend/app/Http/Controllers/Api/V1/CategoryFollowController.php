<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\CategoryFollow;
use App\Traits\ApiResponses;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryFollowController extends Controller
{
    use ApiResponses;

    // ── POST /categories/{category}/follow ─────────────────────────────────

    public function toggle(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'city_id' => 'nullable|integer|exists:cities,id',
        ]);

        $userId = $request->user()->id;
        $cityId = $data['city_id'] ?? null;

        $existing = CategoryFollow::where('user_id', $userId)
            ->where('category_id', $category->id)
            ->where('city_id', $cityId)
            ->first();

        if ($existing) {
            $existing->delete();
            return $this->successResponse(
                ['is_following' => false],
                'تم إلغاء متابعة التصنيف'
            );
        }

        CategoryFollow::create([
            'user_id'     => $userId,
            'category_id' => $category->id,
            'city_id'     => $cityId,
        ]);

        return $this->successResponse(
            ['is_following' => true],
            'تم متابعة التصنيف — سيتم إشعارك عند وجود إعلانات جديدة'
        );
    }

    // ── GET /follows ──────────────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $follows = CategoryFollow::with(['category', 'city'])
            ->where('user_id', $request->user()->id)
            ->latest('created_at')
            ->get()
            ->map(fn (CategoryFollow $f) => [
                'id'       => $f->id,
                'category' => [
                    'id'      => $f->category->id,
                    'name_ar' => $f->category->name_ar,
                    'icon'    => $f->category->icon,
                ],
                'city' => $f->city ? [
                    'id'      => $f->city->id,
                    'name_ar' => $f->city->name_ar,
                ] : null,
                'created_at' => $f->created_at?->toISOString(),
            ]);

        return $this->successResponse($follows);
    }

    // ── GET /categories/{category}/follow-status ─────────────────────────────

    public function status(Request $request, Category $category): JsonResponse
    {
        $isFollowing = CategoryFollow::where('user_id', $request->user()->id)
            ->where('category_id', $category->id)
            ->exists();

        return $this->successResponse(['is_following' => $isFollowing]);
    }
}
