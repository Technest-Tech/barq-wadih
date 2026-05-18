<?php

namespace App\Http\Controllers\Api\V1;

use App\Models\StaticPage;
use Illuminate\Http\JsonResponse;

class StaticPageController extends BaseController
{
    /**
     * GET /api/v1/pages/{slug}
     * Public — returns published page by slug.
     */
    public function show(string $slug): JsonResponse
    {
        $page = StaticPage::where('slug', $slug)
            ->where('is_published', true)
            ->first();

        if (! $page) {
            return $this->errorResponse('الصفحة غير موجودة.', 404);
        }

        return $this->successResponse($page);
    }
}
