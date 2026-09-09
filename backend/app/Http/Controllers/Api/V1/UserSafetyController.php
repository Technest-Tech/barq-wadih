<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ReportReason;
use App\Models\Report;
use App\Models\User;
use App\Models\UserBlock;
use App\Rules\AcceptableContent;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rules\Enum;

class UserSafetyController extends BaseController
{
    public function blockedUsers(Request $request): JsonResponse
    {
        return $this->successResponse([
            'user_ids' => $request->user()->blockedUsers()->pluck('users.id')->values(),
        ]);
    }

    public function status(Request $request, User $user): JsonResponse
    {
        $actor = $request->user();

        return $this->successResponse([
            'is_blocked' => $actor->hasBlocked($user),
            'interaction_blocked' => $actor->cannotInteractWith($user),
        ]);
    }

    public function block(Request $request, User $user): JsonResponse
    {
        $actor = $request->user();

        if ($actor->is($user)) {
            return $this->errorResponse('لا يمكنك حظر حسابك.', 422);
        }

        $data = $request->validate([
            'conversation_id' => ['nullable', 'string', 'max:160'],
        ]);

        $report = DB::transaction(function () use ($actor, $user, $data) {
            UserBlock::firstOrCreate([
                'blocker_id' => $actor->id,
                'blocked_id' => $user->id,
            ]);

            // App Review 1.2 requires the block action itself to notify the
            // developer, so every block also enters the moderation queue.
            $report = Report::firstOrNew([
                'reporter_id' => $actor->id,
                'reported_user_id' => $user->id,
            ]);

            if (! $report->exists || $report->status?->value !== 'pending') {
                $report->fill([
                    'ad_id' => null,
                    'conversation_id' => $data['conversation_id'] ?? null,
                    'reason' => ReportReason::ProhibitedContent,
                    'description' => 'بلاغ تلقائي: قام المستخدم بحظر هذا الحساب بسبب محتوى أو سلوك غير لائق.',
                    'status' => 'pending',
                    'admin_id' => null,
                    'admin_action' => null,
                    'admin_note' => null,
                    'resolved_at' => null,
                ])->save();
            } elseif (! $report->conversation_id && isset($data['conversation_id'])) {
                $report->update(['conversation_id' => $data['conversation_id']]);
            }

            return $report;
        });

        return $this->successResponse(
            [
                'is_blocked' => true,
                'report_submitted' => true,
                'report_id' => $report->id,
            ],
            'تم حظر المستخدم وإبلاغ فريق الإشراف. اختفى محتواه من صفحتك ولن يتمكن أي منكما من التواصل مع الآخر.',
        );
    }

    public function unblock(Request $request, User $user): JsonResponse
    {
        UserBlock::query()
            ->where('blocker_id', $request->user()->id)
            ->where('blocked_id', $user->id)
            ->delete();

        return $this->successResponse(['is_blocked' => false], 'تم إلغاء الحظر.');
    }

    public function report(Request $request, User $user): JsonResponse
    {
        $actor = $request->user();

        if ($actor->is($user)) {
            return $this->errorResponse('لا يمكنك الإبلاغ عن حسابك.', 422);
        }

        $data = $request->validate([
            'reason' => ['required', new Enum(ReportReason::class)],
            'description' => ['nullable', 'string', 'max:1000'],
            'conversation_id' => ['nullable', 'string', 'max:160'],
        ]);

        $report = Report::firstOrNew([
            'reporter_id' => $actor->id,
            'reported_user_id' => $user->id,
        ]);

        if ($report->exists && $report->status?->value === 'pending') {
            return $this->errorResponse('لقد أبلغت عن هذا المستخدم مسبقاً.', 409);
        }

        $report->fill([
            'ad_id' => null,
            'conversation_id' => $data['conversation_id'] ?? null,
            'reason' => $data['reason'],
            'description' => $data['description'] ?? null,
            'status' => 'pending',
            'admin_id' => null,
            'admin_action' => null,
            'admin_note' => null,
            'resolved_at' => null,
        ])->save();

        return $this->successResponse(null, 'تم إرسال البلاغ وسيتم مراجعته خلال 24 ساعة.');
    }

    public function checkContent(Request $request): JsonResponse
    {
        $request->validate([
            'text' => ['required', 'string', 'max:5000', new AcceptableContent],
        ]);

        return $this->successResponse(['allowed' => true]);
    }
}
