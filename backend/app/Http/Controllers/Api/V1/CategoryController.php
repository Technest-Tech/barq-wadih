<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class CategoryController extends BaseController
{
    /**
     * GET /api/v1/categories
     *
     * Returns a full hierarchical tree:
     *   - All active top-level categories
     *   - Each with their active children (ordered by sort_order)
     *   - fields_count included via withCount
     *
     * Cached for 1 hour — invalidated by AdminCategoryController.
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $categories = Cache::remember('categories:tree', 3600, fn () =>
                Category::query()
                    ->topLevel()
                    ->active()
                    ->ordered()
                    ->withCount('fields')
                    ->with($this->childrenTreeEager())
                    ->get()
            );
        } catch (\Throwable) {
            $categories = Category::query()
                ->topLevel()
                ->active()
                ->ordered()
                ->withCount('fields')
                ->with($this->childrenTreeEager())
                ->get();
        }

        return $this->successResponse(
            CategoryResource::collection($categories),
            __('Retrieved categories tree')
        );
    }

    /**
     * Eager-load constraint for the subcategory tree: active children, and
     * each child's own active children (a third level — e.g. طيور → حمام/دجاج/بط),
     * all ordered and with their field counts.
     */
    private function childrenTreeEager(): array
    {
        $childConstraint = fn ($q) => $q
            ->active()
            ->ordered()
            ->withCount('fields')
            ->with([
                'children' => fn ($q2) => $q2
                    ->active()
                    ->ordered()
                    ->withCount('fields'),
            ]);

        return ['children' => $childConstraint];
    }
}
