<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\BaseController;
use App\Models\StaticPage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminStaticPageController extends BaseController
{
    /**
     * GET /api/v1/admin/pages
     */
    public function index(): JsonResponse
    {
        $pages = StaticPage::orderBy('updated_at', 'desc')->get();

        return $this->successResponse($pages);
    }

    /**
     * GET /api/v1/admin/pages/{page}
     */
    public function show(StaticPage $page): JsonResponse
    {
        return $this->successResponse($page);
    }

    /**
     * POST /api/v1/admin/pages
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title_ar'            => 'required|string|max:200',
            'title_en'            => 'required|string|max:200',
            'slug'                => 'required|string|max:100|unique:static_pages,slug',
            'content_ar'          => 'required|string',
            'content_en'          => 'required|string',
            'meta_description_ar' => 'nullable|string|max:300',
            'meta_description_en' => 'nullable|string|max:300',
            'is_published'        => 'boolean',
        ]);

        $page = StaticPage::create($data);

        return $this->successResponse($page, 'تم إنشاء الصفحة بنجاح.', 201);
    }

    /**
     * PUT /api/v1/admin/pages/{page}
     */
    public function update(Request $request, StaticPage $page): JsonResponse
    {
        $data = $request->validate([
            'title_ar'            => 'sometimes|string|max:200',
            'title_en'            => 'sometimes|string|max:200',
            'slug'                => 'sometimes|string|max:100|unique:static_pages,slug,' . $page->id,
            'content_ar'          => 'sometimes|string',
            'content_en'          => 'sometimes|string',
            'meta_description_ar' => 'nullable|string|max:300',
            'meta_description_en' => 'nullable|string|max:300',
            'is_published'        => 'boolean',
        ]);

        $page->update($data);

        return $this->successResponse($page->fresh(), 'تم تحديث الصفحة بنجاح.');
    }

    /**
     * DELETE /api/v1/admin/pages/{page}
     */
    public function destroy(StaticPage $page): JsonResponse
    {
        $page->delete();

        return $this->successResponse(null, 'تم حذف الصفحة بنجاح.');
    }
}
