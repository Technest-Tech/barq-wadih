<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Api\V1\BaseController;
use App\Models\Category;
use App\Models\CategoryField;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class AdminCategoryController extends BaseController
{
    /**
     * GET /api/v1/admin/categories
     *
     * Hierarchical category tree with counts.
     */
    public function index(): JsonResponse
    {
        $categories = Category::whereNull('parent_id')
            ->with(['children' => fn ($q) => $q->withCount(['ads', 'fields'])->orderBy('sort_order')])
            ->withCount(['ads', 'fields'])
            ->orderBy('sort_order')
            ->get();

        return $this->successResponse($categories);
    }

    /**
     * POST /api/v1/admin/categories
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name_ar'             => 'required|string|max:100',
            'name_en'             => 'required|string|max:100',
            'icon'                => 'nullable|string|max:50',
            'image'               => 'nullable|string|max:255',
            'parent_id'           => 'nullable|exists:categories,id',
            'description_ar'      => 'nullable|string|max:500',
            'description_en'      => 'nullable|string|max:500',
            'commission_rate'     => 'nullable|numeric|min:0|max:100',
            'is_free'             => 'boolean',
            'is_active'           => 'boolean',
            'sort_order'          => 'integer|min:0',
            'meta_keywords'       => 'nullable|string|max:500',
            'prohibited_keywords' => 'nullable|array',
        ]);

        $category = Category::create($data);
        Cache::forget('categories:tree');

        return $this->successResponse($category, 'تم إنشاء التصنيف بنجاح.', 201);
    }

    /**
     * PUT /api/v1/admin/categories/{category}
     */
    public function update(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'name_ar'             => 'sometimes|string|max:100',
            'name_en'             => 'sometimes|string|max:100',
            'icon'                => 'nullable|string|max:50',
            'image'               => 'nullable|string|max:255',
            'parent_id'           => 'nullable|exists:categories,id',
            'description_ar'      => 'nullable|string|max:500',
            'description_en'      => 'nullable|string|max:500',
            'commission_rate'     => 'nullable|numeric|min:0|max:100',
            'is_free'             => 'boolean',
            'is_active'           => 'boolean',
            'sort_order'          => 'integer|min:0',
            'meta_keywords'       => 'nullable|string|max:500',
            'prohibited_keywords' => 'nullable|array',
        ]);

        // Prevent circular parent reference
        if (isset($data['parent_id']) && $data['parent_id'] == $category->id) {
            return $this->errorResponse('لا يمكن تعيين التصنيف كأب لنفسه.', 422);
        }

        $category->update($data);
        Cache::forget('categories:tree');

        return $this->successResponse($category->fresh(), 'تم تحديث التصنيف بنجاح.');
    }

    /**
     * POST /api/v1/admin/categories/{category}/toggle
     */
    public function toggleActive(Category $category): JsonResponse
    {
        $category->update(['is_active' => !$category->is_active]);
        Cache::forget('categories:tree');

        $status = $category->is_active ? 'تفعيل' : 'تعطيل';

        return $this->successResponse($category->fresh(), "تم {$status} التصنيف بنجاح.");
    }

    /**
     * POST /api/v1/admin/categories/reorder
     *
     * Batch update sort_order for categories.
     */
    public function reorder(Request $request): JsonResponse
    {
        $request->validate([
            'items'              => 'required|array|min:1',
            'items.*.id'         => 'required|exists:categories,id',
            'items.*.sort_order' => 'required|integer|min:0',
        ]);

        foreach ($request->input('items') as $item) {
            Category::where('id', $item['id'])->update(['sort_order' => $item['sort_order']]);
        }
        Cache::forget('categories:tree');

        return $this->successResponse(null, 'تم تحديث الترتيب بنجاح.');
    }

    // ── Category Field Management ────────────────────────────────────────────

    /**
     * GET /api/v1/admin/categories/{category}/fields
     */
    public function fields(Category $category): JsonResponse
    {
        $fields = $category->fields()->orderBy('sort_order')->get();

        return $this->successResponse($fields);
    }

    /**
     * POST /api/v1/admin/categories/{category}/fields
     */
    public function storeField(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'field_key'       => 'required|string|max:50',
            'label_ar'        => 'required|string|max:100',
            'label_en'        => 'required|string|max:100',
            'field_type'      => 'required|string|in:text,number,select,checkbox,radio,textarea,date',
            'options'         => 'nullable|array',
            'is_required'     => 'boolean',
            'is_filterable'   => 'boolean',
            'sort_order'      => 'integer|min:0',
            'placeholder_ar'  => 'nullable|string|max:200',
            'placeholder_en'  => 'nullable|string|max:200',
            'validation_rules'=> 'nullable|array',
        ]);

        $field = $category->fields()->create($data);

        return $this->successResponse($field, 'تم إضافة الحقل بنجاح.', 201);
    }

    /**
     * PUT /api/v1/admin/fields/{field}
     */
    public function updateField(Request $request, CategoryField $field): JsonResponse
    {
        $data = $request->validate([
            'field_key'       => 'sometimes|string|max:50',
            'label_ar'        => 'sometimes|string|max:100',
            'label_en'        => 'sometimes|string|max:100',
            'field_type'      => 'sometimes|string|in:text,number,select,checkbox,radio,textarea,date',
            'options'         => 'nullable|array',
            'is_required'     => 'boolean',
            'is_filterable'   => 'boolean',
            'sort_order'      => 'integer|min:0',
            'placeholder_ar'  => 'nullable|string|max:200',
            'placeholder_en'  => 'nullable|string|max:200',
            'validation_rules'=> 'nullable|array',
        ]);

        $field->update($data);

        return $this->successResponse($field->fresh(), 'تم تحديث الحقل بنجاح.');
    }

    /**
     * DELETE /api/v1/admin/fields/{field}
     */
    public function deleteField(CategoryField $field): JsonResponse
    {
        $field->delete();

        return $this->successResponse(null, 'تم حذف الحقل بنجاح.');
    }
}
