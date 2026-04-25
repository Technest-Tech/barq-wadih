<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\CampaignStatus;
use App\Enums\CampaignTargetType;
use App\Http\Controllers\Api\V1\BaseController;
use App\Models\Notification;
use App\Models\NotificationCampaign;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminNotificationController extends BaseController
{
    /**
     * GET /admin/notifications/campaigns
     */
    public function index(Request $request): JsonResponse
    {
        $query = NotificationCampaign::with('admin:id,name')
            ->latest();

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($q = $request->query('q')) {
            $query->where(function ($sub) use ($q) {
                $sub->where('title_ar', 'LIKE', "%{$q}%")
                    ->orWhere('title_en', 'LIKE', "%{$q}%");
            });
        }

        $paginated = $query->paginate($request->integer('per_page', 20));

        $items = $paginated->getCollection()->map(fn (NotificationCampaign $c) => [
            'id'               => $c->id,
            'title_ar'         => $c->title_ar,
            'title_en'         => $c->title_en,
            'target_type'      => $c->target_type->value,
            'target_type_label'=> $c->target_type->label(),
            'status'           => $c->status->value,
            'status_label'     => $c->status->label(),
            'recipients_count' => $c->recipients_count ?? 0,
            'delivered_count'  => $c->delivered_count ?? 0,
            'scheduled_at'     => $c->scheduled_at?->toISOString(),
            'sent_at'          => $c->sent_at?->toISOString(),
            'admin'            => $c->admin ? ['id' => $c->admin->id, 'name' => $c->admin->name] : null,
            'created_at'       => $c->created_at->toISOString(),
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
     * POST /admin/notifications/campaigns
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title_ar'           => ['required', 'string', 'max:255'],
            'title_en'           => ['nullable', 'string', 'max:255'],
            'body_ar'            => ['required', 'string', 'max:1000'],
            'body_en'            => ['nullable', 'string', 'max:1000'],
            'target_type'        => ['required', 'in:all,city,category,specific_users'],
            'target_city_id'     => ['nullable', 'integer', 'exists:cities,id'],
            'target_category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'target_user_ids'    => ['nullable', 'array'],
            'target_user_ids.*'  => ['integer', 'exists:users,id'],
            'data'               => ['nullable', 'array'],
            'scheduled_at'       => ['nullable', 'date', 'after:now'],
        ]);

        $status = isset($validated['scheduled_at'])
            ? CampaignStatus::Scheduled
            : CampaignStatus::Draft;

        $campaign = NotificationCampaign::create([
            'admin_id'           => $request->user()->id,
            'title_ar'           => $validated['title_ar'],
            'title_en'           => $validated['title_en'] ?? null,
            'body_ar'            => $validated['body_ar'],
            'body_en'            => $validated['body_en'] ?? null,
            'target_type'        => $validated['target_type'],
            'target_city_id'     => $validated['target_city_id'] ?? null,
            'target_category_id' => $validated['target_category_id'] ?? null,
            'target_user_ids'    => $validated['target_user_ids'] ?? null,
            'data'               => $validated['data'] ?? null,
            'status'             => $status->value,
            'scheduled_at'       => $validated['scheduled_at'] ?? null,
        ]);

        return $this->successResponse([
            'id'     => $campaign->id,
            'status' => $campaign->status->value,
        ], 'تم إنشاء الحملة بنجاح', 201);
    }

    /**
     * GET /admin/notifications/campaigns/{campaign}
     */
    public function show(NotificationCampaign $campaign): JsonResponse
    {
        $campaign->load(['admin:id,name', 'targetCity:id,name_ar', 'targetCategory:id,name_ar']);

        return $this->successResponse([
            'id'                => $campaign->id,
            'title_ar'          => $campaign->title_ar,
            'title_en'          => $campaign->title_en,
            'body_ar'           => $campaign->body_ar,
            'body_en'           => $campaign->body_en,
            'target_type'       => $campaign->target_type->value,
            'target_type_label' => $campaign->target_type->label(),
            'target_city'       => $campaign->targetCity ? [
                'id' => $campaign->targetCity->id, 'name_ar' => $campaign->targetCity->name_ar,
            ] : null,
            'target_category' => $campaign->targetCategory ? [
                'id' => $campaign->targetCategory->id, 'name_ar' => $campaign->targetCategory->name_ar,
            ] : null,
            'target_user_ids'   => $campaign->target_user_ids,
            'data'              => $campaign->data,
            'status'            => $campaign->status->value,
            'status_label'      => $campaign->status->label(),
            'recipients_count'  => $campaign->recipients_count ?? 0,
            'delivered_count'   => $campaign->delivered_count ?? 0,
            'scheduled_at'      => $campaign->scheduled_at?->toISOString(),
            'sent_at'           => $campaign->sent_at?->toISOString(),
            'admin'             => $campaign->admin ? ['id' => $campaign->admin->id, 'name' => $campaign->admin->name] : null,
            'created_at'        => $campaign->created_at->toISOString(),
            'updated_at'        => $campaign->updated_at->toISOString(),
        ]);
    }

    /**
     * PUT /admin/notifications/campaigns/{campaign}
     */
    public function update(Request $request, NotificationCampaign $campaign): JsonResponse
    {
        if ($campaign->status !== CampaignStatus::Draft) {
            return $this->errorResponse('لا يمكن تعديل حملة تم إرسالها أو جدولتها', 422);
        }

        $validated = $request->validate([
            'title_ar'           => ['sometimes', 'string', 'max:255'],
            'title_en'           => ['nullable', 'string', 'max:255'],
            'body_ar'            => ['sometimes', 'string', 'max:1000'],
            'body_en'            => ['nullable', 'string', 'max:1000'],
            'target_type'        => ['sometimes', 'in:all,city,category,specific_users'],
            'target_city_id'     => ['nullable', 'integer', 'exists:cities,id'],
            'target_category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'target_user_ids'    => ['nullable', 'array'],
            'data'               => ['nullable', 'array'],
        ]);

        $campaign->update($validated);

        return $this->successResponse(['id' => $campaign->id], 'تم تحديث الحملة');
    }

    /**
     * DELETE /admin/notifications/campaigns/{campaign}
     */
    public function destroy(NotificationCampaign $campaign): JsonResponse
    {
        if ($campaign->status !== CampaignStatus::Draft) {
            return $this->errorResponse('لا يمكن حذف حملة تم إرسالها', 422);
        }

        $campaign->delete();

        return $this->successResponse(null, 'تم حذف الحملة');
    }

    /**
     * POST /admin/notifications/campaigns/{campaign}/send
     */
    public function send(NotificationCampaign $campaign): JsonResponse
    {
        if ($campaign->status === CampaignStatus::Sent) {
            return $this->errorResponse('تم إرسال هذه الحملة بالفعل', 422);
        }

        $recipientIds = $this->resolveRecipients($campaign);
        $count        = count($recipientIds);

        // Create notification records for each recipient
        $notifications = [];
        $now = now();
        foreach ($recipientIds as $userId) {
            $notifications[] = [
                'user_id'    => $userId,
                'type'       => 'campaign',
                'title_ar'   => $campaign->title_ar,
                'title_en'   => $campaign->title_en,
                'body_ar'    => $campaign->body_ar,
                'body_en'    => $campaign->body_en,
                'data'       => json_encode(array_merge($campaign->data ?? [], [
                    'campaign_id' => $campaign->id,
                ])),
                'channel'    => 'push',
                'is_read'    => false,
                'sent_at'    => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        // Batch insert (500 per chunk)
        foreach (array_chunk($notifications, 500) as $chunk) {
            Notification::insert($chunk);
        }

        $campaign->update([
            'status'           => CampaignStatus::Sent->value,
            'sent_at'          => $now,
            'recipients_count' => $count,
            'delivered_count'  => $count, // TODO: Real FCM delivery tracking (Sprint 10)
        ]);

        return $this->successResponse([
            'id'               => $campaign->id,
            'recipients_count' => $count,
        ], "تم إرسال الحملة إلى {$count} مستخدم");
    }

    /**
     * POST /admin/notifications/campaigns/{campaign}/schedule
     */
    public function schedule(Request $request, NotificationCampaign $campaign): JsonResponse
    {
        if ($campaign->status === CampaignStatus::Sent) {
            return $this->errorResponse('تم إرسال هذه الحملة بالفعل', 422);
        }

        $validated = $request->validate([
            'scheduled_at' => ['required', 'date', 'after:now'],
        ]);

        $campaign->update([
            'status'       => CampaignStatus::Scheduled->value,
            'scheduled_at' => $validated['scheduled_at'],
        ]);

        return $this->successResponse([
            'id'           => $campaign->id,
            'scheduled_at' => $campaign->fresh()->scheduled_at->toISOString(),
        ], 'تم جدولة الحملة');
    }

    /**
     * GET /admin/notifications/stats
     */
    public function stats(): JsonResponse
    {
        return $this->successResponse([
            'total_campaigns'  => NotificationCampaign::count(),
            'sent_campaigns'   => NotificationCampaign::where('status', CampaignStatus::Sent->value)->count(),
            'draft_campaigns'  => NotificationCampaign::where('status', CampaignStatus::Draft->value)->count(),
            'scheduled_campaigns' => NotificationCampaign::where('status', CampaignStatus::Scheduled->value)->count(),
            'total_recipients' => (int) NotificationCampaign::sum('recipients_count'),
            'total_notifications' => Notification::count(),
            'unread_notifications' => Notification::unread()->count(),
        ]);
    }

    // ── Private helpers ────────────────────────────────────────────────────

    /**
     * Resolve target user IDs based on campaign target type.
     *
     * @return int[]
     */
    private function resolveRecipients(NotificationCampaign $campaign): array
    {
        return match ($campaign->target_type) {
            CampaignTargetType::All => User::where('is_active', true)->pluck('id')->toArray(),

            CampaignTargetType::City => User::where('is_active', true)
                ->whereHas('ads', fn ($q) => $q->where('city_id', $campaign->target_city_id))
                ->pluck('id')->toArray(),

            CampaignTargetType::Category => User::where('is_active', true)
                ->whereHas('categoryFollows', fn ($q) => $q->where('category_id', $campaign->target_category_id))
                ->pluck('id')->toArray(),

            CampaignTargetType::SpecificUsers => $campaign->target_user_ids ?? [],
        };
    }
}
