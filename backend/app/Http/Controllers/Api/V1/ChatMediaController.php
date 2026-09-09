<?php

namespace App\Http\Controllers\Api\V1;

use App\Models\Ad;
use App\Models\User;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ChatMediaController extends BaseController
{
    public function __construct(private readonly ImageService $images) {}

    /**
     * Upload a chat image or voice note to the application's configured disk.
     *
     * The conversation id is deterministic (ad{id}_u{low}_u{high}), so the
     * backend can verify membership without needing to mirror Firestore data.
     */
    public function store(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'type' => ['required', 'string', Rule::in(['image', 'voice'])],
        ]);

        $type = $request->string('type')->toString();
        $request->validate([
            'file' => $type === 'image'
                ? ['required', 'file', 'max:10240', 'mimes:jpg,jpeg,png,webp,heic,heif']
                : ['required', 'file', 'max:20480', 'extensions:m4a,aac,mp4', 'mimetypes:audio/mp4,audio/x-m4a,audio/aac,video/mp4,application/octet-stream'],
        ]);

        $context = $this->conversationContext($id);
        if ($context === null) {
            return $this->errorResponse('معرّف المحادثة غير صالح.', 422);
        }

        /** @var User $actor */
        $actor = $request->user();
        if (! in_array($actor->id, $context['user_ids'], true)) {
            return $this->errorResponse('ليس لديك صلاحية لرفع ملفات لهذه المحادثة.', 403);
        }

        $ad = Ad::query()->find($context['ad_id']);
        if (! $ad) {
            return $this->errorResponse('الإعلان المرتبط بالمحادثة غير موجود.', 404);
        }

        if (! in_array((int) $ad->user_id, $context['user_ids'], true)) {
            return $this->errorResponse('أطراف المحادثة لا تطابق صاحب الإعلان.', 403);
        }

        $otherId = $context['user_ids'][0] === $actor->id
            ? $context['user_ids'][1]
            : $context['user_ids'][0];
        $other = User::query()->find($otherId);

        if (! $other || $actor->cannotInteractWith($other)) {
            return $this->errorResponse('لا يمكن إرسال ملفات لهذا المستخدم.', 403);
        }

        $file = $request->file('file');

        if ($type === 'image') {
            $stored = $this->images->storeVariants(
                $file->getRealPath(),
                "chat/{$id}/images",
            );

            return $this->successResponse(data: [
                'type' => 'image',
                'url' => $stored['image_url'],
                'thumbnail_url' => $stored['thumbnail_url'],
                'mime_type' => 'image/webp',
                'size' => $stored['file_size'],
            ], message: 'تم رفع الصورة.');
        }

        $path = $this->images->store($file, "chat/{$id}/voice");

        return $this->successResponse(data: [
            'type' => 'voice',
            'url' => $this->images->url($path),
            'mime_type' => $file->getMimeType() ?: 'audio/mp4',
            'size' => $file->getSize(),
        ], message: 'تم رفع التسجيل الصوتي.');
    }

    /**
     * @return array{ad_id:int,user_ids:array{0:int,1:int}}|null
     */
    private function conversationContext(string $id): ?array
    {
        if (! preg_match('/^ad(\d+)_u(\d+)_u(\d+)$/', $id, $matches)) {
            return null;
        }

        return [
            'ad_id' => (int) $matches[1],
            'user_ids' => [(int) $matches[2], (int) $matches[3]],
        ];
    }
}
